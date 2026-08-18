/// 2단계(관광지 마커) 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음.
/// 결정 배경: Document/init_plan.md 4-2 섹션.
class TourismConfig {
  TourismConfig._();

  /// 재조회 트리거 임계치 — 마지막 조회 중심에서 이 비율(현재 뷰포트 반경 대비) 이상 이동하면
  /// 현재 위치를 새 중심으로 재조회 (4-2 섹션 "약 50%").
  static const double refetchDistanceRatio = 0.5;

  /// 지도 이동이 잦을 때 재조회 API 호출이 과도해지지 않도록 하는 디바운스 시간.
  static const Duration refetchDebounce = Duration(milliseconds: 400);

  /// 로컬 캐시(tourism_spots) 최초 동기화 이후, 이 기간이 지나면 앱 시작 시 백그라운드로
  /// 재동기화(전체 재다운로드 후 통째 교체) — Document/temp.md "tour_spot 로컬 캐싱" 3번 참고.
  static const Duration syncStaleThreshold = Duration(days: 7);

  /// 좌표 중복(같은 건물 내 여러 매장) 그룹의 항목 수가 이 값을 넘으면, 리스트를 바로 보여주는
  /// 대신 카테고리 버튼만 먼저 노출 — 서버 `game-config.ts`의 `DUPLICATE_SPOT_LIST_FILTER_THRESHOLD`와
  /// 반드시 같은 값을 유지할 것(로컬 캐시 도입 이후 이 판단을 클라이언트가 직접 하므로 중복 정의됨).
  static const int duplicateSpotListFilterThreshold = 15;
}
