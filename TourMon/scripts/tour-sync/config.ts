// TourAPI 배치 동기화 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음.

// 한 번의 areaBasedSyncList2 호출당 최대 행 수 — 클수록 호출 수(일일 1,000회 한도) 절약
export const NUM_OF_ROWS = 1000;

// 일일 1,000회 한도 대비 소프트 경고 임계치 — 넘으면 로그로 경고만 (하드 차단 안 함, 수동 실행 스크립트)
export const CALL_BUDGET_WARNING_THRESHOLD = 900;

// 7단계 — 국문/영문 관광지 좌표 매칭 반경 (scripts/tour-sync/eng-match.ts).
// "완전 일치" 판정 반경 — 경복궁 사례(국문/영문 좌표가 소수점까지 동일)처럼 사실상 같은 점으로
// 볼 아주 좁은 허용오차. 부동소수점 비교를 ST_DWithin으로 대신하기 위한 값.
export const ENG_MATCH_EXACT_TOLERANCE_METERS = 0.1;

// exact tolerance 안에서 후보가 없을 때만 쓰는 2차 허용 반경 — 너무 넓히면 인접한 다른 관광지와
// 오매칭될 위험이 커져서 좁게 유지(init_plan.md 4-7 섹션).
export const ENG_MATCH_FALLBACK_RADIUS_METERS = 5;

// 좌표 중복(같은 건물 내 여러 매장) 그룹핑 반경 — dedup-spots.ts. 실측(2026-08-17)으로 5m 안에서는
// 클러스터 연쇄(transitive chaining)가 발생하지 않음을 확인함(Document/temp.md "관광지 마커 — 좌표 중복" 참고).
export const DUPLICATE_SPOT_GROUP_RADIUS_METERS = 5;
