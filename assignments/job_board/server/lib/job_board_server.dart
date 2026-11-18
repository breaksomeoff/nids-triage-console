/// Back-end of the job board: REST API, SQLite storage and CV files.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

import 'src/api.dart';

export 'src/api.dart' show JobBoardApi, maxCvBytes;
export 'src/passwords.dart' show PasswordHasher;
export 'src/store.dart' show Store;

/// Full server handler: `/api/...` goes to [api]; anything else is served
/// from [webDirectory] (the Flutter web build), when given.
Handler createServerHandler(
  JobBoardApi api, {
  Directory? webDirectory,
  bool log = false,
}) {
  final apiHandler = api.handler;
  final staticHandler = webDirectory == null
      ? null
      : createStaticHandler(webDirectory.path, defaultDocument: 'index.html');

  Future<Response> route(Request request) async {
    if (request.url.path == 'api' || request.url.path.startsWith('api/')) {
      return apiHandler(request);
    }
    if (staticHandler == null) return Response.notFound('Not found');
    final response = await staticHandler(request);
    // Revalidate every time, so the phone always gets the latest build.
    return response.change(headers: {'cache-control': 'no-cache'});
  }

  var pipeline = const Pipeline();
  if (log) pipeline = pipeline.addMiddleware(_logRequests);
  return pipeline.addMiddleware(_cors).addHandler(route);
}

/// Logs method, path and status. The query string is left out on purpose:
/// the CV link carries the session token there.
Handler _logRequests(Handler inner) => (request) async {
  final watch = Stopwatch()..start();
  final response = await inner(request);
  stdout.writeln(
    '${DateTime.now().toIso8601String().substring(11, 19)} '
    '${request.method.padRight(6)} ${response.statusCode} '
    '/${request.url.path} (${watch.elapsedMilliseconds} ms)',
  );
  return response;
};

/// Lets the app run from another origin during development
/// (`flutter run -d chrome`). Auth uses a bearer token, not cookies.
Handler _cors(Handler inner) {
  const headers = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
    'access-control-allow-headers': 'authorization, content-type',
  };
  return (request) async {
    if (request.method == 'OPTIONS') return Response(204, headers: headers);
    final response = await inner(request);
    return response.change(headers: headers);
  };
}
