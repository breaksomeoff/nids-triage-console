import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory stand-in for the real server, same routes and JSON shapes.
class FakeBackend {
  final companies = <Map<String, dynamic>>[];
  final passwords = <String, String>{};
  final sessions = <String, int>{};
  final jobs = <Map<String, dynamic>>[];
  final applications = <Map<String, dynamic>>[];
  var _nextId = 1;

  late final client = MockClient.streaming((request, bodyStream) async {
    final body = await bodyStream.toBytes();
    final response = _handle(request, body);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: {'content-type': 'application/json'},
    );
  });

  ({int statusCode, String body}) _json(Object? data, [int status = 200]) =>
      (statusCode: status, body: data == null ? '' : jsonEncode(data));

  ({int statusCode, String body}) _error(int status, String message) =>
      _json({'error': message}, status);

  Map<String, dynamic>? _company(http.BaseRequest r) {
    final auth = r.headers['authorization'];
    final id = auth == null ? null : sessions[auth.substring(7)];
    return companies.where((c) => c['id'] == id).firstOrNull;
  }

  ({int statusCode, String body}) _handle(
    http.BaseRequest request,
    List<int> bytes,
  ) {
    final path = request.url.path;
    final method = request.method;
    Map<String, dynamic> body() =>
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    if (method == 'POST' && path == '/api/companies') {
      final b = body();
      if (passwords.containsKey(b['email'])) {
        return _error(409, 'Esiste già un account con questa email.');
      }
      final company = {'id': _nextId++, 'name': b['name'], 'email': b['email']};
      companies.add(company);
      passwords[b['email'] as String] = b['password'] as String;
      return _json(company, 201);
    }
    if (method == 'POST' && path == '/api/sessions') {
      final b = body();
      if (passwords[b['email']] != b['password']) {
        return _error(401, 'Email o password non corretti.');
      }
      final company = companies.firstWhere((c) => c['email'] == b['email']);
      final token = 'token${_nextId++}';
      sessions[token] = company['id'] as int;
      return _json({'token': token, 'company': company}, 201);
    }
    if (method == 'DELETE' && path == '/api/sessions') {
      sessions.remove(request.headers['authorization']?.substring(7));
      return _json(null, 204);
    }
    if (method == 'GET' && path == '/api/jobs') {
      return _json([
        for (final j in jobs.reversed) {...j}..remove('companyId'),
      ]);
    }
    final applyMatch = RegExp(r'^/api/jobs/(\d+)/applications$')
        .firstMatch(path);
    if (method == 'POST' && applyMatch != null) {
      final fields = (request as http.MultipartRequest).fields;
      final file = request.files.single;
      final application = {
        'id': _nextId++,
        'jobId': int.parse(applyMatch[1]!),
        'firstName': fields['firstName'],
        'lastName': fields['lastName'],
        'email': fields['email'],
        'cvFilename': file.filename,
        'cvSize': file.length,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      applications.add(application);
      return _json(application, 201);
    }

    final company = _company(request);
    if (company == null) return _error(401, 'Sessione non valida.');

    if (method == 'POST' && path == '/api/jobs') {
      final b = body();
      final job = {
        'id': _nextId++,
        'companyId': company['id'],
        'companyName': company['name'],
        'title': b['title'],
        'description': b['description'],
        'location': b['location'],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      jobs.add(job);
      return _json(job, 201);
    }
    if (method == 'GET' && path == '/api/my/jobs') {
      return _json([
        for (final j in jobs.reversed.where(
          (j) => j['companyId'] == company['id'],
        ))
          {
            ...j,
            'applicationCount': applications
                .where((a) => a['jobId'] == j['id'])
                .length,
          }..remove('companyId'),
      ]);
    }
    if (method == 'GET' && applyMatch != null) {
      final jobId = int.parse(applyMatch[1]!);
      return _json(applications.where((a) => a['jobId'] == jobId).toList());
    }
    return _error(404, 'Non trovato.');
  }
}
