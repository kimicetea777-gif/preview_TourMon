/// 게임 로직 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음(Next.js game-config.ts와 동일 패턴).
/// 게스트 모드는 서버에 상태가 없어서 이런 클라이언트 전용 제약은 여기서만 관리 —
/// 6단계에서 회원 대상 서버 측 검증이 붙을 때 TourMon/src/lib/game-config.ts에도 동일 값 추가될 자리.
class GameConfig {
  GameConfig._();

  /// 파트너 알 최대 동시 진행 개수 (init_plan.md 4-3 섹션).
  static const int maxPartnerEggs = 2;

  /// 알 보관함 화면에서 걸음수 진행도를 자동 새로고침하는 주기 — 로컬 sqlite 조회만 하고
  /// 외부 API를 안 부르는 화면이라 짧게 잡아도 비용 부담 없음(지도 화면의 재조회 디바운스와
  /// 달리 네트워크 호출을 아낄 이유가 없음).
  static const Duration eggInventoryRefreshInterval = Duration(seconds: 3);

  /// 알 획득 쿨타임(스팟당 하루 1회)의 "하루" 경계 — TourMon/src/lib/game-config.ts의
  /// DAILY_RESET_HOUR_KST와 동일 값을 미러링. 로그인 상태의 서버 판정과 클라이언트 프리체크가
  /// 같은 기준을 쓰지 않으면 자정 부근에서 서로 어긋남(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md 참고).
  static const int dailyResetHourKst = 4;

  /// 로그인 상태에서 걸음수를 서버로 동기화하는 주기 — init_plan.md 4-3 "걸음수 서버 동기화":
  /// "포그라운드 중 3~5분 간격 + 백그라운드 전환 시 즉시 1회"(실시간 스트리밍 금지, 배터리/야외
  /// 신호 불안정 문제). 게스트는 이 동기화 자체를 안 함 — 서버에 상태가 없으므로.
  static const Duration stepServerSyncInterval = Duration(minutes: 4);

  /// 지도 화면 파트너 알 박스의 "오늘 소모 칼로리" 재미용 추정치 계수 — 이 앱은 몸무게/키 등
  /// 개인정보를 안 받으므로 정확한 칼로리 계산은 애초에 불가능해, "걸음수 × 이 값"으로 단순화
  /// (2026-08-18 결정, Document/temp.md 참고). 정밀 계산 목적 아님, 재미 요소로만 표시.
  static const double caloriesPerStep = 0.05;
}
