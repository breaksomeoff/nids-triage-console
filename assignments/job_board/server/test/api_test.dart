import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:job_board_server/job_board_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final _pdf = utf8.encode('%PDF-1.4\nfake curriculum\n%%EOF');

void main() {
  late Directory tmp;
  late Store store;
  late Handler handler;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('job_board_test');
    store = Store.inMemory();
    final api = JobBoardApi(
      store: store,
      cvDirectory: tmp,
      hasher: PasswordHasher(iterations: 10),
    );
    handler = createServerHandler(api);
  });

  tearDown(() {
    store.close();
    tmp.deleteSync(recursive: true);
  });

  Future<Response> send(
    String method,
    String path, {
    Object? json,
    String? token,
    Map<String, String> headers = const {},
    Object? body,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: json != null ? jsonEncode(json) : body,
      headers: {
        if (json != null) 'content-type': 'application/json',
        'authorization': ?(token == null ? null : 'Bearer $token'),
        ...headers,
      },
    ),
  );

  Future<dynamic> decode(Response r) async =>
      jsonDecode(await r.readAsString());

  Future<String> registerAndLogin(String email) async {
    await send(
      'POST',
      '/api/companies',
      json: {'name': 'Acme $email', 'email': email, 'password': 'password1'},
    );
    final r = await send(
      'POST',
      '/api/sessions',
      json: {'email': email, 'password': 'password1'},
    );
    return (await decode(r))['token'] as String;
  }

  Future<int> publish(String token, String title) async {
    final r = await send(
      'POST',
      '/api/jobs',
      token: token,
      json: {
        'title': title,
        'description': 'Descrizione',
        'location': 'Salerno',
      },
    );
    expect(r.statusCode, 201);
    return (await decode(r))['id'] as int;
  }

  Future<Response> apply(int jobId, {List<int>? cv, String email = 'm@r.it'}) {
    const boundary = 'testboundary';
    final b = BytesBuilder();
    void field(String name, String value) => b.add(
      utf8.encode(
        '--$boundary\r\ncontent-disposition: form-data; name="$name"\r\n\r\n'
        '$value\r\n',
      ),
    );
    field('firstName', 'Mario');
    field('lastName', 'Rossi');
    field('email', email);
    if (cv != null) {
      b.add(
        utf8.encode(
          '--$boundary\r\ncontent-disposition: form-data; name="cv"; '
          'filename="cv mario.pdf"\r\ncontent-type: application/pdf\r\n\r\n',
        ),
      );
      b.add(cv);
      b.add(utf8.encode('\r\n'));
    }
    b.add(utf8.encode('--$boundary--\r\n'));
    return send(
      'POST',
      '/api/jobs/$jobId/applications',
      headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
      body: b.takeBytes(),
    );
  }

  group('R1/R2/R3 auth', () {
    test('register validates input and rejects duplicate emails', () async {
      var r = await send(
        'POST',
        '/api/companies',
        json: {'name': 'Acme', 'email': 'acme@x.it', 'password': 'short'},
      );
      expect(r.statusCode, 400);

      r = await send(
        'POST',
        '/api/companies',
        json: {'name': 'Acme', 'email': 'Acme@X.it', 'password': 'password1'},
      );
      expect(r.statusCode, 201);
      expect(await decode(r), containsPair('email', 'acme@x.it'));

      r = await send(
        'POST',
        '/api/companies',
        json: {'name': 'Altra', 'email': 'acme@x.it', 'password': 'password1'},
      );
      expect(r.statusCode, 409);
    });

    test('login checks the password; logout invalidates the token', () async {
      await send(
        'POST',
        '/api/companies',
        json: {'name': 'Acme', 'email': 'a@x.it', 'password': 'password1'},
      );
      var r = await send(
        'POST',
        '/api/sessions',
        json: {'email': 'a@x.it', 'password': 'wrongpass'},
      );
      expect(r.statusCode, 401);

      final token = await registerAndLogin('a@x.it');
      r = await send('GET', '/api/me', token: token);
      expect(await decode(r), containsPair('name', 'Acme'));

      r = await send('DELETE', '/api/sessions', token: token);
      expect(r.statusCode, 204);
      r = await send('GET', '/api/me', token: token);
      expect(r.statusCode, 401);
    });
  });

  test(
    'R4/R5 publishing needs auth; jobs appear on the public board',
    () async {
      var r = await send(
        'POST',
        '/api/jobs',
        json: {'title': 'X', 'description': 'Y'},
      );
      expect(r.statusCode, 401);

      final token = await registerAndLogin('a@x.it');
      r = await send(
        'POST',
        '/api/jobs',
        token: token,
        json: {'title': ' ', 'description': 'Y'},
      );
      expect(r.statusCode, 400);

      final id = await publish(token, 'Flutter developer');
      final jobs = await decode(await send('GET', '/api/jobs')) as List;
      expect(jobs.single['title'], 'Flutter developer');
      expect(jobs.single['companyName'], 'Acme a@x.it');
      expect(jobs.single.containsKey('applicationCount'), isFalse);

      r = await send('GET', '/api/jobs/$id');
      expect(await decode(r), containsPair('location', 'Salerno'));
      expect((await send('GET', '/api/jobs/999')).statusCode, 404);
    },
  );

  test('R6 application requires all fields and a PDF', () async {
    final token = await registerAndLogin('a@x.it');
    final id = await publish(token, 'Job');

    expect((await apply(id)).statusCode, 400);
    expect((await apply(id, cv: utf8.encode('not a pdf'))).statusCode, 400);
    expect((await apply(id, cv: _pdf, email: 'nope')).statusCode, 400);
    expect((await apply(999, cv: _pdf)).statusCode, 404);
    expect(
      (await apply(id, cv: List.filled(maxCvBytes + 1, 0x25))).statusCode,
      413,
    );

    final r = await apply(id, cv: _pdf);
    expect(r.statusCode, 201);
    expect(await decode(r), containsPair('cvFilename', 'cv mario.pdf'));
    expect(tmp.listSync(), hasLength(1));
  });

  test('R7 only the owner sees applications and downloads the CV', () async {
    final owner = await registerAndLogin('a@x.it');
    final other = await registerAndLogin('b@x.it');
    final id = await publish(owner, 'Job');
    final appId = (await decode(await apply(id, cv: _pdf)))['id'];

    final mine = await decode(await send('GET', '/api/my/jobs', token: owner));
    expect(mine.single['applicationCount'], 1);
    final others = await decode(
      await send('GET', '/api/my/jobs', token: other),
    );
    expect(others, isEmpty);

    var r = await send('GET', '/api/jobs/$id/applications', token: owner);
    expect((await decode(r)).single['lastName'], 'Rossi');
    r = await send('GET', '/api/jobs/$id/applications', token: other);
    expect(r.statusCode, 404);
    r = await send('GET', '/api/jobs/$id/applications');
    expect(r.statusCode, 401);

    r = await send('GET', '/api/applications/$appId/cv?token=$owner');
    expect(r.statusCode, 200);
    expect(r.headers['content-type'], 'application/pdf');
    expect(await r.read().expand((c) => c).toList(), _pdf);
    r = await send('GET', '/api/applications/$appId/cv?token=$other');
    expect(r.statusCode, 404);
  });

  test('data survives a restart (persistent database file)', () async {
    final path = '${tmp.path}/db.sqlite';
    var s = Store.open(path);
    s.createCompany(
      name: 'Acme',
      email: 'a@x.it',
      passwordHash: 'h',
      passwordSalt: 's',
    );
    s.close();
    s = Store.open(path);
    expect(s.findCredentials('a@x.it')?.company.name, 'Acme');
    s.close();
  });
}
