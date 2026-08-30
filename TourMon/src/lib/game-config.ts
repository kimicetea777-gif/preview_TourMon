// 게임 로직 튜닝값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음.

// 알 획득 판정 반경 — 원래 100m였으나(init_plan.md 4-2 섹션 원안), 롯데월드 같은 대형 복합시설에서
// 한 자리에 서서 대표 spot 여러 개(4개)를 동시에 반경 안에 넣고 알을 여러 번 받을 수 있는 문제가
// 발견돼 50m로 축소(2026-08-17 결정), 이후 30m로 추가 축소(2026-08-18). 완전히 막히진 않음(실측:
// 롯데월드 사례에서 4개→2개로 줄어드는 수준) — 근본 해결은 아니고 완화 조치.
// 2026-08-27: GPS 오차로 반경 안에 못 들어가는 케이스가 잦아 60m로 2배 확대(대형 복합시설
// 다중 획득 재발 가능성은 감수).
// 2026-08-29: 60m는 대형 복합시설 다중 획득이 너무 헐거워져 45m로 조정(30m GPS 미도달과
// 60m 과다 획득 사이 절충).
export const EGG_ACQUISITION_RADIUS_METERS = 45;

// 알 획득 쿨타임(스팟당 하루 1회)의 "하루" 경계 — 자정이 아니라 KST 새벽 4시로 정의.
// 롤링 24시간은 클라이언트 프리체크(캘린더 날짜 기준)와 자정 부근에서 어긋나고, 자정 고정은 실제
// 관광지를 돌아다니는 밤 시간대(23시~1시)에 세션이 갈라지는 문제가 있어 4시로 확정
// (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md, 2026-08-16 논의).
export const DAILY_RESET_HOUR_KST = 4;

// 대표 spot에 묶인 좌표 중복 리스트(같은 건물 내 여러 매장)가 이 값을 넘으면 전체를 한 번에
// 내려주지 않고 content_type 버튼만 먼저 보여줌 — 버튼 탭 시에만 해당 카테고리를 불러옴
// (Document/temp.md "관광지 마커 — 좌표 중복" 결정 배경, 롯데월드타워 145건 케이스 대응).
export const DUPLICATE_SPOT_LIST_FILTER_THRESHOLD = 15;

// 게스트 알 유통기한 — 미소진 egg_vouchers를 이 일수 뒤에 정리(egg-voucher-cleanup.ts)하고,
// Flutter도 같은 값(GameConfig.guestEggShelfLife)으로 로컬 알의 부화 가능 기한을 표시/판정한다.
// 90일로 넉넉히 잡은 이유: 관광지 방문 기반이라 재접속 텀이 길 수 있어, 정직하게 늦게 돌아온
// 사용자가 위조 시도와 똑같이 거부당하는 오탐을 줄이기 위함(init_plan.md DB 스키마 egg_vouchers 섹션).
export const GUEST_EGG_SHELF_LIFE_DAYS = 90;

// 거리 서버 동기화(POST /api/distance/sync) 타당성 게이트 — 경과 시간(users.last_distance_sync_at
// 기준) 대비 물리적으로 가능한 최대 거리로 델타를 클램프한다. 거부가 아니라 초과분을 조용히 버림
// (포켓몬 GO가 속도 초과분을 무시하는 방식). 입력이 Health Connect STEPS라 차·자전거는 소스에서
// 이미 배제 → PoGo 10.5km/h처럼 빡빡할 이유 없음. 15면 sync 4분당 약 1,000m(≈20,000 steps/h
// 상당)로 러너(이상적 유저)도 안 닿음. 어뷰징 패턴이 실측되면 이력 로그(Document/temp.md
// "추후 확장")로 조정.
export const MAX_PLAUSIBLE_SPEED_KMH = 15;

// 위 클램프의 경과 시간 상한 — 오래 방치된 계정이 첫 sync에서 elapsed가 커져 클램프가 헐거워지는
// 것을 막아 "쌓아둘 수 있는 미청구 거리 = 최대 하루치"로 캡(포켓몬 GO Adventure Sync도 소급
// 적립을 제한된 양만 함). 파이프라인의 게임 데이(DAILY_RESET_HOUR_KST)와 통일(Document/temp.md
// Part 2 미결 사항).
export const DISTANCE_SYNC_ELAPSED_CAP_HOURS = 24;

// 파트너 알 최대 동시 진행 개수 — Flutter GameConfig.maxPartnerEggs 미러(init_plan.md 4-3). 파트너
// 상태 자체는 순수 기기 로컬이고 서버엔 없음(Document/temp.md Part 1) — 이 값은 /api/distance/sync가
// 받은 partnerEggIds 개수의 싼 sanity 가드로만 쓰인다.
export const MAX_PARTNER_EGGS = 2;
