import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'passwords.dart';
import 'store.dart';

/// Maximum accepted CV size.
const maxCvBytes = 5 * 1024 * 1024;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// REST API of the job board, mounted under `/api`.
///
/// Error bodies are `{"error": "<message>"}`, with messages in Italian so the
/// app can show them as they are.
class JobBoardApi {
  JobBoardApi({
    required this.store,
    required this.cvDirectory,
    PasswordHasher? hasher,
  }) : hasher = hasher ?? PasswordHasher();

  final Store store;
  final Directory cvDirectory;
  final PasswordHasher hasher;

  Handler get handler {
    final router = Router(notFoundHandler: (_) => _error(404, 'Non trovato.'))
      // Companies: registration and session (login/logout).
      ..post('/api/companies', _register)
      ..post('/api/sessions', _login)
      ..delete('/api/sessions', _logout)
      ..get('/api/me', _me)
      // Public board.
      ..get('/api/jobs', _listJobs)
      ..get('/api/jobs/<id|[0-9]+>', _getJob)
      ..post('/api/jobs/<id|[0-9]+>/applications', _apply)
      // Reserved area.
      ..post('/api/jobs', _createJob)
      ..get('/api/my/jobs', _myJobs)
      ..get('/api/jobs/<id|[0-9]+>/applications', _listApplications)
      ..get('/api/applications/<id|[0-9]+>/cv', _downloadCv);
    return router.call;
  }

  // Auth

  Future<Response> _register(Request request) async {
    final body = await _readJson(request);
    if (body == null) return _error(400, 'Richiesta non valida.');
    final name = _field(body, 'name');
    final email = _field(body, 'email').toLowerCase();
    final password = body['password'] is String
        ? body['password'] as String
        : '';

    if (name.isEmpty) {
      return _error(400, 'Il nome dell\'azienda è obbligatorio.');
    }
    if (!_emailPattern.hasMatch(email)) {
      return _error(400, 'Inserisci un indirizzo email valido.');
    }
    if (password.length < 8) {
      return _error(400, 'La password deve avere almeno 8 caratteri.');
    }

    final hashed = hasher.hash(password);
    final company = store.createCompany(
      name: name,
      email: email,
      passwordHash: hashed.hash,
      passwordSalt: hashed.salt,
    );
    if (company == null) {
      return _error(409, 'Esiste già un account con questa email.');
    }
    return _json(company.toJson(), status: 201);
  }

  Future<Response> _login(Request request) async {
    final body = await _readJson(request);
    if (body == null) return _error(400, 'Richiesta non valida.');
    final email = _field(body, 'email').toLowerCase();
    final password = body['password'] is String
        ? body['password'] as String
        : '';

    final credentials = store.findCredentials(email);
    if (credentials == null ||
        !hasher.verify(
          password,
          hash: credentials.hash,
          salt: credentials.salt,
        )) {
      return _error(401, 'Email o password non corretti.');
    }
    final token = randomToken();
    store.createSession(hashToken(token), credentials.company.id);
    return _json({
      'token': token,
      'company': credentials.company.toJson(),
    }, status: 201);
  }

  Response _logout(Request request) {
    final token = _bearerToken(request);
    if (token != null) store.deleteSession(hashToken(token));
    return Response(204);
  }

  Response _me(Request request) {
    final company = _authenticate(request);
    if (company == null) return _unauthorized();
    return _json(company.toJson());
  }

  // Public board

  Response _listJobs(Request request) =>
      _json([for (final job in store.listJobs()) job.toJson()]);

  Response _getJob(Request request, String id) {
    final job = store.findJob(int.parse(id));
    if (job == null) return _error(404, 'Annuncio non trovato.');
    return _json(job.toJson());
  }

  Future<Response> _apply(Request request, String id) async {
    final job = store.findJob(int.parse(id));
    if (job == null) return _error(404, 'Annuncio non trovato.');

    final length = request.contentLength;
    if (length != null && length > maxCvBytes + 64 * 1024) return _tooLarge();

    final _Multipart form;
    try {
      final parsed = await _readMultipart(request);
      if (parsed == null) return _error(400, 'Richiesta non valida.');
      form = parsed;
    } on _TooLargeException {
      return _tooLarge();
    } on MimeMultipartException {
      return _error(400, 'Richiesta non valida.');
    }

    final firstName = (form.fields['firstName'] ?? '').trim();
    final lastName = (form.fields['lastName'] ?? '').trim();
    final email = (form.fields['email'] ?? '').trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      return _error(400, 'Nome e cognome sono obbligatori.');
    }
    if (!_emailPattern.hasMatch(email)) {
      return _error(400, 'Inserisci un indirizzo email valido.');
    }
    final cv = form.cv;
    if (cv == null || cv.bytes.isEmpty) {
      return _error(400, 'Allega il curriculum.');
    }
    if (!_isPdf(cv.bytes)) {
      return _error(400, 'Il curriculum deve essere un file PDF.');
    }

    final storedName = '${randomToken(16)}.pdf';
    final file = File('${cvDirectory.path}/$storedName');
    await file.writeAsBytes(cv.bytes, flush: true);
    try {
      final application = store.createApplication(
        jobId: job.id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        cvFilename: _cleanFilename(cv.filename),
        cvStoredName: storedName,
        cvSize: cv.bytes.length,
      );
      return _json(application.toJson(), status: 201);
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  // Reserved area

  Future<Response> _createJob(Request request) async {
    final company = _authenticate(request);
    if (company == null) return _unauthorized();
    final body = await _readJson(request);
    if (body == null) return _error(400, 'Richiesta non valida.');

    final title = _field(body, 'title');
    final description = _field(body, 'description');
    final location = _field(body, 'location');
    if (title.isEmpty) return _error(400, 'Il titolo è obbligatorio.');
    if (title.length > 120) {
      return _error(400, 'Il titolo può avere al massimo 120 caratteri.');
    }
    if (description.isEmpty) {
      return _error(400, 'La descrizione è obbligatoria.');
    }
    if (location.length > 120) {
      return _error(400, 'La sede può avere al massimo 120 caratteri.');
    }

    final job = store.createJob(
      companyId: company.id,
      title: title,
      description: description,
      location: location,
    );
    return _json(job.toJson(), status: 201);
  }

  Response _myJobs(Request request) {
    final company = _authenticate(request);
    if (company == null) return _unauthorized();
    return _json([
      for (final job in store.listJobsOfCompany(company.id)) job.toJson(),
    ]);
  }

  Response _listApplications(Request request, String id) {
    final company = _authenticate(request);
    if (company == null) return _unauthorized();
    final job = store.findJob(int.parse(id));
    // Other companies' jobs look like they do not exist.
    if (job == null || job.companyId != company.id) {
      return _error(404, 'Annuncio non trovato.');
    }
    return _json([for (final a in store.listApplications(job.id)) a.toJson()]);
  }

  /// Streams the CV. Also accepts the session token as `?token=`, because the
  /// app opens the file in the browser, which cannot send headers.
  Response _downloadCv(Request request, String id) {
    final company = _authenticate(request, allowQueryToken: true);
    if (company == null) return _unauthorized();
    final application = store.findApplication(int.parse(id));
    if (application == null || application.companyId != company.id) {
      return _error(404, 'Candidatura non trovata.');
    }
    final file = File('${cvDirectory.path}/${application.cvStoredName}');
    if (!file.existsSync()) return _error(404, 'Curriculum non trovato.');

    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': 'application/pdf',
        'content-length': '${file.lengthSync()}',
        'content-disposition':
            "inline; filename*=UTF-8''${Uri.encodeComponent(application.cvFilename)}",
        'cache-control': 'no-store',
      },
    );
  }

  // Helpers

  Company? _authenticate(Request request, {bool allowQueryToken = false}) {
    final token =
        _bearerToken(request) ??
        (allowQueryToken ? request.url.queryParameters['token'] : null);
    if (token == null || token.isEmpty) return null;
    return store.companyForSession(hashToken(token));
  }

  static String? _bearerToken(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length).trim();
  }

  static Future<Map<String, Object?>?> _readJson(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String _field(Map<String, Object?> body, String key) {
    final value = body[key];
    return value is String ? value.trim() : '';
  }

  static Future<_Multipart?> _readMultipart(Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null) return null;
    final mediaType = MediaType.parse(contentType);
    final boundary = mediaType.parameters['boundary'];
    if (mediaType.mimeType != 'multipart/form-data' || boundary == null) {
      return null;
    }

    final fields = <String, String>{};
    _Upload? cv;
    final parts = MimeMultipartTransformer(boundary).bind(request.read());
    await for (final part in parts) {
      final disposition = HeaderValue.parse(
        part.headers['content-disposition'] ?? '',
      );
      final name = disposition.parameters['name'];
      final filename = disposition.parameters['filename'];

      final builder = BytesBuilder(copy: false);
      await for (final chunk in part) {
        builder.add(chunk);
        if (builder.length > maxCvBytes) throw _TooLargeException();
      }
      final bytes = builder.takeBytes();
      if (name == 'cv' && filename != null) {
        cv = _Upload(filename, bytes);
      } else if (name != null) {
        fields[name] = utf8.decode(bytes, allowMalformed: true);
      }
    }
    return _Multipart(fields, cv);
  }

  static bool _isPdf(Uint8List bytes) =>
      bytes.length >= 5 && ascii.decode(bytes.sublist(0, 5)) == '%PDF-';

  static String _cleanFilename(String filename) {
    final base = filename.split(RegExp(r'[/\\]')).last.trim();
    final clean = base.replaceAll(RegExp(r'[\x00-\x1f"]'), '');
    if (clean.isEmpty) return 'curriculum.pdf';
    return clean.length > 100 ? clean.substring(clean.length - 100) : clean;
  }

  static Response _json(Object body, {int status = 200}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static Response _error(int status, String message) =>
      _json({'error': message}, status: status);

  static Response _unauthorized() =>
      _error(401, 'Sessione non valida o scaduta. Accedi di nuovo.');

  static Response _tooLarge() =>
      _error(413, 'Il curriculum può pesare al massimo 5 MB.');
}

class _Upload {
  _Upload(this.filename, this.bytes);

  final String filename;
  final Uint8List bytes;
}

class _Multipart {
  _Multipart(this.fields, this.cv);

  final Map<String, String> fields;
  final _Upload? cv;
}

class _TooLargeException implements Exception {}
