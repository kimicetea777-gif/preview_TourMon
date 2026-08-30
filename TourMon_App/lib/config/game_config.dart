/// 게임 로직 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음(Next.js game-config.ts와 동일 패턴).
/// 게스트 모드는 서버에 상태가 없어서 이런 클라이언트 전용 제약은 여기서만 관리 —
/// 6단계에서 회원 대상 서버 측 검증이 붙을 때 TourMon/src/lib/game-config.ts에도 동일 값 추가될 자리.
class GameConfig {
  GameConfig._();

  /// 파트너 알 최대 동시 진행 개수 (init_plan.md 4-3 섹션).
  static const int maxPartnerEggs = 2;

  /// 알 보관함 화면에서 거리 진행도를 자동 새로고침하는 주기 — 로컬 sqlite 조회만 하고
  /// 외부 API를 안 부르는 화면이라 짧게 잡아도 비용 부담 없음(지도 화면의 재조회 디바운스와
  /// 달리 네트워크 호출을 아낄 이유가 없음).
  static const Duration eggInventoryRefreshInterval = Duration(seconds: 3);

  /// 알 획득 쿨타임(스팟당 하루 1회)의 "하루" 경계 — TourMon/src/lib/game-config.ts의
  /// DAILY_RESET_HOUR_KST와 동일 값을 미러링. 로그인 상태의 서버 판정과 클라이언트 프리체크가
  /// 같은 기준을 쓰지 않으면 자정 부근에서 서로 어긋남(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md 참고).
  static const int dailyResetHourKst = 4;

  /// Health Connect 거리 데이터를 조회/서버로 동기화하는 주기 — init_plan.md 4-3 "걸음수 서버
  /// 동기화"(Health Connect 전환 후에도 동일 카덴스 유지): "포그라운드 중 3~5분 간격 + 백그라운드
  /// 전환 시 즉시 1회"(실시간 스트리밍 금지, 배터리/야외 신호 불안정 문제). 게스트는 서버 동기화
  /// 자체를 안 하지만 로컬 파트너알 적립은 게스트도 이 주기로 동작. mock-location 감지
  /// (Document/temp.md "통합 결정")도 이 주기에 맞춰 1회씩 샘플링.
  static const Duration distanceServerSyncInterval = Duration(minutes: 4);

  /// 지도 화면 파트너 알 박스의 "오늘 소모 칼로리" 재미용 추정치 계수 — 이 앱은 몸무게/키 등
  /// 개인정보를 안 받으므로 정확한 칼로리 계산은 애초에 불가능해, "거리(km) × 이 값"으로 단순화
  /// (2026-08-18 결정, Document/temp.md 참고. Health Connect 전환으로 걸음수 기준에서 거리 기준으로
  /// 재정의 — 평균 보폭 약 0.7m 기준 기존 걸음당 계수(0.05)와 비슷한 체감이 되도록 ×1000/0.7 스케일).
  /// 정밀 계산 목적 아님, 재미 요소로만 표시.
  static const double caloriesPerKm = 70;

  /// 게스트(로그인 전) 로컬 알의 유통기한 — `acquiredAt` 기준 이 기간이 지나면 "굳어서" 부화
  /// 불가. 서버 `egg_vouchers` TTL(`TourMon/src/lib/game-config.ts` `GUEST_EGG_SHELF_LIFE_DAYS`)과
  /// 같은 값을 미러링해야 함 — 클라이언트 선제 안내와 서버의 실제 강제(voucher 삭제)가 어긋나면
  /// 안 됨(init_plan.md DB 스키마 egg_vouchers 섹션, "클라이언트 측 선제 체크" 결정). 회원
  /// `user_eggs`엔 적용 안 함(계정에 귀속된 실제 인벤토리라 시간 만료로 잃으면 손실이 큼).
  static const Duration guestEggShelfLife = Duration(days: 90);

  /// 유통기한이 이 기간 이내로 남은 게스트 알은 보관함에서 경고색으로 강조.
  static const Duration guestEggExpiryWarningWindow = Duration(days: 7);

  /// STEPS → 거리(m) 환산 계수(성인 평균 보폭, m/step) — 삼성 헬스가 Health Connect에
  /// `DISTANCE_DELTA`는 안 쓰고 `STEPS`만 동기화하는 게 실기기에서 확인돼(2026-08-26),
  /// `DistanceTrackerService`가 `DISTANCE_DELTA` 대신 `STEPS`를 조회해 이 계수로 직접 환산.
  /// 개인별 키/성별 보정은 하지 않음 — 게임 재화 적립용 근사치라 정밀도보다 단순함 우선(고정값
  /// 결정, 필요해지면 그때 프로필 기반으로 확장).
  static const double stepsToMetersFactor = 0.75;
}
