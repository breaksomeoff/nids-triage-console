import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 password hashing. Plain passwords are never
/// stored.
class PasswordHasher {
  PasswordHasher({this.iterations = 120000});

  final int iterations;
  final _random = Random.secure();

  ({String hash, String salt}) hash(String password) {
    final salt = Uint8List.fromList(
      List.generate(16, (_) => _random.nextInt(256)),
    );
    return (
      hash: base64.encode(_pbkdf2(password, salt)),
      salt: base64.encode(salt),
    );
  }

  bool verify(String password, {required String hash, required String salt}) {
    final expected = base64.decode(hash);
    final actual = _pbkdf2(password, base64.decode(salt));
    // Constant-time comparison.
    var diff = expected.length ^ actual.length;
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      diff |= expected[i] ^ actual[i];
    }
    return diff == 0;
  }

  /// One 32-byte block of PBKDF2 (RFC 8018) with HMAC-SHA256.
  Uint8List _pbkdf2(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}

/// Random URL-safe token, used for sessions and stored file names.
String randomToken([int bytes = 32]) {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(bytes, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

/// Session tokens are stored hashed, so a leaked database does not leak
/// usable tokens.
String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();
