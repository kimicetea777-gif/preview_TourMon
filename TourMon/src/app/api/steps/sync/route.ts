// 6단계 Phase 5 — 걸음수 서버 동기화 (init_plan.md 4-3 "걸음수 서버 동기화" 🔄🔐).
// 로컬 SQLite가 항상 진짜 값을 보관하고, 서버는 주기적으로 델타만 전달받아 자기 사본에 누적함 —
// 동기화 실패해도 다음 시도 때 따라잡히므로 데이터 유실 없음(클라이언트가 델타를 들고 재시도).
import { and, eq, isNull, sql } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { stepSyncLogs, userEggs } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";

export async function POST(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const deltaSteps = Number(body?.deltaSteps);
  if (!Number.isFinite(deltaSteps) || deltaSteps < 0) {
    return Response.json({ error: "deltaSteps는 0 이상의 숫자여야 함" }, { status: 400 });
  }

  const activePartnerFilter = and(
    eq(userEggs.userId, auth.sub),
    eq(userEggs.isPartner, true),
    isNull(userEggs.hatchedAt),
  );

  const eggs = await db.transaction(async (tx) => {
    if (deltaSteps > 0) {
      await tx
        .update(userEggs)
        .set({ stepsAccumulated: sql`${userEggs.stepsAccumulated} + ${deltaSteps}` })
        .where(activePartnerFilter);
      await tx.insert(stepSyncLogs).values({ userId: auth.sub, deltaSteps });
    }
    return tx
      .select({
        id: userEggs.id,
        stepsAccumulated: userEggs.stepsAccumulated,
        targetSteps: userEggs.targetSteps,
      })
      .from(userEggs)
      .where(activePartnerFilter);
  });

  return Response.json({ eggs });
}
