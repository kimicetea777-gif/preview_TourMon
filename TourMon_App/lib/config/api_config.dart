/// TourMon Next.js API 서버 설정값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음.
/// `map_config.dart`의 `TILE_SERVER_BASE_URL` 패턴과 동일하게 실행 시점에 주입받음.
class ApiConfig {
  ApiConfig._();

  /// TourMon Next.js API 서버 베이스 URL.
  ///   Android 에뮬레이터: --dart-define=API_BASE_URL=http://10.0.2.2:3000
  ///   iOS 시뮬레이터:     --dart-define=API_BASE_URL=http://localhost:3000
  ///   실기기(같은 LAN):   --dart-define=API_BASE_URL=http://<개발 PC LAN IP>:3000
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static String get requireBaseUrl {
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL이 주입되지 않음 — flutter run 실행 시 '
        '--dart-define=API_BASE_URL=http://... 를 반드시 지정할 것',
      );
    }
    return baseUrl;
  }

  /// 앱 전체 HTTP 요청 공용 타임아웃 — 이전엔 어느 호출에도 없어서 신호 약함/서버 다운 시
  /// 로딩 화면이 무한정 멈출 수 있었음. Next.js API뿐 아니라 Auth_Server(AS) 호출
  /// (`auth_session.dart`)도 같은 값을 재사용 — 서버가 둘이어도 기대 지연 프로필이 다를 이유가
  /// 없어서 별도 상수로 안 나눔.
  static const Duration requestTimeout = Duration(seconds: 15);
}
