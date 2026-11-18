import 'package:flutter/foundation.dart';

/// Base URL of the back-end, always ending with `/`.
///
/// - `--dart-define=API_URL=http://host:8080` overrides everything.
/// - On the web the app is served by the back-end itself, so it uses the
///   page's own origin.
/// - Otherwise it assumes the Android emulator, where 10.0.2.2 is the host.
Uri apiBaseUrl() {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) {
    return Uri.parse(override.endsWith('/') ? override : '$override/');
  }
  if (kIsWeb) return Uri.parse('${Uri.base.origin}/');
  return Uri.parse('http://10.0.2.2:8080/');
}
