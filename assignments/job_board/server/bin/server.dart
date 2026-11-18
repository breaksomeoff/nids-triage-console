import 'dart:io';

import 'package:job_board_server/job_board_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Starts the server.
///
/// Environment variables:
/// - `PORT` (default 8080)
/// - `DATA_DIR`: database and CVs (default `data`)
/// - `WEB_DIR`: Flutter web build to serve (default `../app/build/web`)
Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final dataDir = Directory(env['DATA_DIR'] ?? 'data');
  final cvDir = Directory('${dataDir.path}/cv')..createSync(recursive: true);
  final webDir = Directory(env['WEB_DIR'] ?? '../app/build/web');

  final store = Store.open('${dataDir.path}/job_board.db');
  final api = JobBoardApi(store: store, cvDirectory: cvDir);
  final hasWeb = File('${webDir.path}/index.html').existsSync();

  final server = await shelf_io.serve(
    createServerHandler(api, webDirectory: hasWeb ? webDir : null, log: true),
    InternetAddress.anyIPv4,
    port,
  );

  stdout.writeln('Job board server on port ${server.port}');
  stdout.writeln('Data: ${dataDir.absolute.path}');
  stdout.writeln(
    hasWeb
        ? 'Web app: ${webDir.absolute.path}'
        : 'Web app not found in ${webDir.path} (API only). '
              'Build it with: cd ../app && flutter build web',
  );
  for (final interface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  )) {
    for (final address in interface.addresses) {
      stdout.writeln('  http://${address.address}:${server.port}/');
    }
  }

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    store.close();
    exit(0);
  });
}
