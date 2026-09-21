// TourAPI 배치 동기화(runTourSync + runDedupeSpots) 진행 상태 — 인메모리(단일 mini-PC 인스턴스
// 전제, 인스턴스가 여러 대로 늘어나면 재검토 필요). 6천여 건 upsert가 수십 초~분 단위로 걸릴 수 있어
// 어드민 요청-응답 안에서 동기 대기하지 않고 백그라운드로 돌린 뒤 이 상태를 폴링/재조회한다.
//
// 상태를 이 모듈의 최상위 `let`이 아니라 globalThis에 붙인다 — Next.js dev 서버(Turbopack)가
// 라우트 핸들러 모듈을 요청마다 새로 인스턴스화할 수 있어서, 일반 모듈 변수로 두면 POST가 쓴
// "running"/"success" 상태를 페이지의 GET이 못 보고 매번 초기값(idle)만 보는 문제가 있었다
// (실측, 2026-09-15). globalThis는 모듈 재평가와 무관하게 프로세스 전체에서 하나라 이 문제가 없다
// (Prisma client를 globalThis에 캐싱하는 것과 동일한 이유의 표준 우회법).
export type TourSyncStatus =
  | { phase: "idle" }
  | { phase: "running"; startedAt: number }
  | { phase: "success"; startedAt: number; finishedAt: number; summary: string }
  | { phase: "error"; startedAt: number; finishedAt: number; message: string };

const GLOBAL_KEY = Symbol.for("tourmon.admin.tourSyncStatus");

interface GlobalWithStatus {
  [GLOBAL_KEY]?: TourSyncStatus;
}

function store(): GlobalWithStatus {
  return globalThis as unknown as GlobalWithStatus;
}

export function getTourSyncStatus(): TourSyncStatus {
  return store()[GLOBAL_KEY] ?? { phase: "idle" };
}

export function setTourSyncStatus(status: TourSyncStatus): void {
  store()[GLOBAL_KEY] = status;
}

export function isTourSyncRunning(): boolean {
  return getTourSyncStatus().phase === "running";
}
