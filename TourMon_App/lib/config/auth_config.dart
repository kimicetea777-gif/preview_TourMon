/// 6단계 — 개인 Auth_Server(AS) 연동 설정값. `api_config.dart`/`map_config.dart`와 동일하게
/// 하드코딩 금지 원칙에 따라 실행 시점에 `--dart-define`으로 주입받음.
class AuthConfig {
  AuthConfig._();

  /// AS 발급자(issuer) URL — OIDC discovery/JWKS/token 엔드포인트의 기준.
  ///   Android 에뮬레이터: --dart-define=AS_ISSUER_URL=http://10.0.2.2:9000
  static const String issuer = String.fromEnvironment('AS_ISSUER_URL');

  /// AS에 등록된 Public client id (Phase 1, `application.yml`의 `TourMon-mobile`).
  static const String clientId = String.fromEnvironment(
    'AS_CLIENT_ID',
    defaultValue: 'TourMon-mobile',
  );

  /// AS `redirect-uri`와 정확히 일치해야 함 — 언더스코어가 있는 Android applicationId
  /// (`com.tourmon.tourmon_app`)와 달리 RFC 3986 URI 스킴 제약 때문에 별도 스킴을 씀
  /// (init_plan.md 4-1 섹션 참고).
  static const String redirectScheme = 'com.tourmon.app';
  static const String redirectUri = '$redirectScheme:/oauth2redirect';

  static const List<String> scopes = ['openid', 'profile'];

  static String get requireIssuer {
    if (issuer.isEmpty) {
      throw StateError(
        'AS_ISSUER_URL이 주입되지 않음 — flutter run 실행 시 '
        '--dart-define=AS_ISSUER_URL=http://... 를 반드시 지정할 것',
      );
    }
    return issuer;
  }
}
