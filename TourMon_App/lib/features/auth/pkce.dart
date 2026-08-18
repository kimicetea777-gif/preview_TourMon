import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 6단계 — `flutter_appauth`가 내부적으로 처리해주던 PKCE/CSRF/replay 방어값을
/// `flutter_web_auth_2` 마이그레이션에서 직접 생성하기 위한 헬퍼 (Document/temp.md Phase B).
class Pkce {
  Pkce._();

  static String _randomUrlSafeString(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// RFC 7636 권장 길이(32바이트 난수 → base64url 43자).
  static String generateCodeVerifier() => _randomUrlSafeString(32);

  static String generateCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(ascii.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String generateState() => _randomUrlSafeString(32);

  static String generateNonce() => _randomUrlSafeString(32);
}
