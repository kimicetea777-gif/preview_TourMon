/// 게임 로직 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음(Next.js game-config.ts와 동일 패턴).
/// 게스트 모드는 서버에 상태가 없어서 이런 클라이언트 전용 제약은 여기서만 관리 —
/// 6단계에서 회원 대상 서버 측 검증이 붙을 때 TourMon/src/lib/game-config.ts에도 동일 값 추가될 자리.
class GameConfig {
  GameConfig._();

  /// 출시 임시 조치(2026-08-31, `Document/temp.md` "게스트 전용 출시 — 서버에 위치정보를 남기지 않는 구조")
  /// — 계정/로그인 진입점을 전부 비활성화하고 게스트 전용으로 출시한다. 위치기반서비스사업 신고는
  /// 사업자등록을 요구하는데, 개인 개발자에게 그 부담이
  /// 커서, 서버에 사용자와 연결된 위치정보(`user_eggs.tourism_spot_id` + `acquired_at` 트레일)를
  /// 아예 안 남기는 구조로 출시한다. 게스트 획득은 서버에 익명 `egg_vouchers`만 남김.
  ///
  /// ⚠️ 되돌릴 때는 이 플래그 하나만 뒤집으면 안 됨 — [serverEggProximityCheck] 재활성화 +
  /// 위치기반서비스사업 신고 완료 + 그동안 쌓인 게스트 로컬 데이터의 마이그레이션 검증을 **한
  /// 묶음**으로 처리해야 한다(서버 인증을 켜는 순간 좌표 전송이 되살아나 신고 의무가 붙으므로).
  static const bool accountsEnabled = false;

  /// 출시 임시 조치 — 알 획득 반경 판정을 서버(`ST_DWithin`, `acquire`에 lat/lng 전송)가 아니라
  /// 클라이언트가 로컬 캐시 좌표(`TourismSpot.position`)와 [MapConfig.eggAcquisitionRadiusMeters]로
  /// 직접 수행한다. false면 `POST /api/eggs/acquire` 요청 본문에 lat/lng를 싣지 않는다 — 서버로
  /// 좌표가 가는 유일한 경로였음(`Document/temp.md` 같은 절). [accountsEnabled]와 한 묶음으로 되돌림.
  static const bool serverEggProximityCheck = false;

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

  /// 로컬에 쌓인 거리 델타를 서버로 밀어보내는 주기 — init_plan.md 4-3 "걸음수 서버 동기화":
  /// "포그라운드 중 3~5분 간격 + 백그라운드 전환 시 즉시 1회"(실시간 스트리밍 금지, 배터리/야외
  /// 신호 불안정 문제). 거리 측정 이중화(Document/temp.md) 이후로는 GPS 델타가 지도 화면에서
  /// 실시간으로 쌓이고, 이 타이머는 순수하게 "쌓인 pending 델타를 서버로 flush"하는 카덴스로만
  /// 쓰인다(게스트는 flush 자체가 no-op). 화면의 "N분 전 갱신" 안내도 이 값을 단일 소스로 씀.
  static const Duration distanceServerSyncInterval = Duration(minutes: 4);

  /// pedometer 백그라운드 보너스(`paused`~`resumed` 걸음 diff)의 카덴스 상한 — 분당 걸음 수 기준
  /// (Document/temp.md 4번). 이 구간은 GPS/mock-location 감지가 전혀 안 도는 사각지대라, "이동
  /// 속도"가 아니라 "걸음 빈도"로 diff 자체를 클램프한다(서버의 15km/h 속도 클램프는 흔들개가
  /// 만드는 고빈도 걸음을 잘 못 잡음). 200보/분은 전력 질주 수준까지 여유를 둔 값이라 정상
  /// 사용자는 안 걸리고 장시간 방치형 흔들개만 상한에 막힌다. 서버
  /// `TourMon/src/lib/game-config.ts` MAX_PLAUSIBLE_STEPS_PER_MINUTE에 같은 값 미러링.
  static const int maxPlausibleStepsPerMinute = 200;

  /// 위 카덴스 클램프의 경과 시간 절대 상한(시간) — 시스템 시계를 앞으로 돌려 `elapsedMinutes`를
  /// 부풀리는 공격의 피해 규모를 제한하는 "비용 적은 안전장치"(Document/temp.md 4번). 서버
  /// `DISTANCE_SYNC_ELAPSED_CAP_HOURS`와 같은 결(쌓아둘 수 있는 미청구 거리 = 최대 하루치).
  static const int backgroundBonusElapsedCapHours = 24;

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

  /// 걸음 수 → 거리(m) 환산 계수(성인 평균 보폭, m/step) — 거리 측정 이중화(Document/temp.md)
  /// 이후로는 pedometer 보조 경로(`paused`~`resumed` 걸음 diff)에서만 쓴다. 주 경로(GPS)는
  /// 좌표 간 haversine 거리를 그대로 미터로 적립하므로 이 계수를 안 거침. 개인별 키/성별 보정은
  /// 하지 않음 — 게임 재화 적립용 근사치라 정밀도보다 단순함 우선(고정값 결정, 필요해지면 그때
  /// 프로필 기반으로 확장).
  static const double stepsToMetersFactor = 0.75;
}
