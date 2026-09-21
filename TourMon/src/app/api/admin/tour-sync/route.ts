// 어드민 콘솔에서 TourAPI 배치 동기화를 트리거 — build_manual.md "TourAPI 배치 동기화(tour:sync) —
// 아직 자동화 안 됨"이 지적한 수동 실행 문제를 SSH 없이 웹에서 할 수 있게 한다. 6천여 건 upsert가
// 수십 초~분 걸릴 수 있어 응답을 기다리게 하지 않고 백그라운드로 돌린 뒤 /admin/tour-sync가 상태를
// 보여준다(tour-sync-status.ts). tour:sync → tour:dedupe-spots 순서는 반드시 지켜야 함(대표 스팟
// 재계산이 최신 동기화 데이터를 전제) — 그래서 두 단계를 분리 트리거하지 않고 여기서 순차 실행한다.
import { NextResponse } from "next/server";
import { ADMIN_BASE_URL, requireAdminSession } from "@/lib/admin/server-session";
import { isTourSyncRunning, setTourSyncStatus } from "@/lib/admin/tour-sync-status";
import { runDedupeSpots } from "@scripts/tour-sync/dedupe-spots";
import { runTourSync } from "@scripts/tour-sync/sync";

function redirectToPage(origin: string, params: Record<string, string> = {}): NextResponse {
  const url = new URL("/admin/tour-sync", origin);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return NextResponse.redirect(url, 303);
}

export async function POST() {
  const auth = await requireAdminSession();
  if (!auth) return Response.json({ error: "관리자 권한 필요" }, { status: 403 });

  if (isTourSyncRunning()) {
    return redirectToPage(ADMIN_BASE_URL, { error: "already_running" });
  }

  const startedAt = Date.now();
  setTourSyncStatus({ phase: "running", startedAt });

  // 응답을 기다리지 않고 백그라운드로 실행 — await 없이 던져두고 완료/실패는 상태로만 기록한다.
  void (async () => {
    try {
      const syncResult = await runTourSync();
      const dedupeResult = await runDedupeSpots({ dryRun: false });
      setTourSyncStatus({
        phase: "success",
        startedAt,
        finishedAt: Date.now(),
        summary:
          `TourAPI 호출 ${syncResult.callCount}회(활성 지역 ${syncResult.regionCount}개) · ` +
          `중복 그룹 재계산 ${dedupeResult.updatedRows ?? 0}행 반영(클러스터 ${dedupeResult.clusterCount}개, ` +
          `중복 그룹 ${dedupeResult.multiMemberClusterCount}개)`,
      });
    } catch (err) {
      setTourSyncStatus({
        phase: "error",
        startedAt,
        finishedAt: Date.now(),
        message: err instanceof Error ? err.message : String(err),
      });
    }
  })();

  return redirectToPage(ADMIN_BASE_URL, { started: "1" });
}
