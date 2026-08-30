// 6단계 Phase 5 후속 하드닝 — 거리 서버 동기화 재작성
// (Document/temp.md "파트너 알 중복 설정 / 거리 서버 동기화 재검토").
//
// Part 1 (파트너 = 순수 기기 로컬): 서버는 파트너 개념을 갖지 않는다. 클라가 "이번에 거리를
//   적립할 알 id 목록"(partnerEggIds)을 매 sync마다 직접 실어보낸다. 예전 `eq(isPartner, true)`
//   필터를 `inArray(id, partnerEggIds)` + `eq(userId)` + `isNull(hatchedAt)`로 교체.
//
// Part 2 (거리 상한 클램프): users.last_distance_sync_at 기준 경과 시간 × 최대 속도로 델타를
//   클램프한다 — 거부가 아니라 초과분을 조용히 버림(포켓몬 GO 방식). last_distance_sync_at은
//   mock 여부·클램프 여부와 무관하게 항상 now()로 전진 — 안 그러면 버려진 구간이 다음 sync의
//   elapsed에 재포함돼 클램프가 무력화됨. 동시 sync는 users 행 FOR UPDATE로 직렬화.
//
// Part 3-A (로컬↔서버 수렴): 응답으로 파트너 알의 서버 누적값을 돌려줘 클라가 로컬을 서버 값에
//   덮어쓰게 한다(회원은 distance_accumulated_meters가 서버 authoritative).
//
// mockDetected가 true면(클라가 동기화 시점에 Geolocator.isMocked 감지) last_distance_sync_at만
// 전진시키고 알엔 반영하지 않음 — voucher 위조 처리와 같은 결로 조용히 무시(감사 로그 없음).
import { and, eq, inArray, isNull, sql } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { userEggs, users } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";
import {
  DISTANCE_SYNC_ELAPSED_CAP_HOURS,
  MAX_PARTNER_EGGS,
  MAX_PLAUSIBLE_SPEED_KMH,
} from "@/lib/game-config";

export async function POST(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const deltaDistanceMeters = Number(body?.deltaDistanceMeters);
  const mockDetected = Boolean(body?.mockDetected);
  if (!Number.isFinite(deltaDistanceMeters)) {
    return Response.json({ error: "deltaDistanceMeters는 유한한 숫자여야 함" }, { status: 400 });
  }
  // 음수 델타(클라 시계 역행/글리치)는 검증 실패로 막지 않고 0으로 흡수 — 클램프 철학과 동일.
  const requestedMeters = deltaDistanceMeters < 0 ? 0 : deltaDistanceMeters;

  const rawPartnerEggIds = Array.isArray(body?.partnerEggIds) ? body.partnerEggIds : null;
  if (
    !rawPartnerEggIds ||
    rawPartnerEggIds.some((id: unknown) => typeof id !== "string")
  ) {
    return Response.json({ error: "partnerEggIds 문자열 배열이 필요함" }, { status: 400 });
  }
  // 서로 다른 id 개수로 판정 — 클라가 같은 id를 중복해서 실어보내도 상한 검사가 뚫리지 않도록.
  const partnerEggIds = [...new Set(rawPartnerEggIds as string[])];
  if (partnerEggIds.length > MAX_PARTNER_EGGS) {
    return Response.json(
      { error: `partnerEggIds는 최대 ${MAX_PARTNER_EGGS}개` },
      { status: 400 },
    );
  }

  const activePartnerFilter = and(
    inArray(userEggs.id, partnerEggIds),
    eq(userEggs.userId, auth.sub),
    isNull(userEggs.hatchedAt),
  );

  const result = await db.transaction(async (tx) => {
    // 동시 sync 직렬화 — 잠글 행이 users 하나로 명확(temp.md Part 2 "동시성").
    const [userRow] = await tx
      .select({ lastDistanceSyncAt: users.lastDistanceSyncAt })
      .from(users)
      .where(eq(users.id, auth.sub))
      .for("update");
    if (!userRow) return null;

    const now = new Date();
    const elapsedMs = Math.max(0, now.getTime() - userRow.lastDistanceSyncAt.getTime());
    const cappedElapsedMs = Math.min(
      elapsedMs,
      DISTANCE_SYNC_ELAPSED_CAP_HOURS * 3600 * 1000,
    );
    // maxCredit = elapsed × 15 km/h → meters
    const maxCredit = (cappedElapsedMs / 1000) * ((MAX_PLAUSIBLE_SPEED_KMH * 1000) / 3600);
    const applied = Math.floor(Math.min(requestedMeters, maxCredit));

    // 클램프됐든 mock이든 항상 전진 — 이 구간이 다음 elapsed에 재포함되면 클램프가 무의미해짐.
    await tx.update(users).set({ lastDistanceSyncAt: now }).where(eq(users.id, auth.sub));

    if (!mockDetected && applied > 0 && partnerEggIds.length > 0) {
      await tx
        .update(userEggs)
        .set({
          distanceAccumulatedMeters: sql`${userEggs.distanceAccumulatedMeters} + ${applied}`,
        })
        .where(activePartnerFilter);
    }

    // Part 3-A — partnerEggIds 중 본인 소유·미부화 알의 갱신된 서버 누적값(클라가 로컬을 여기에
    // 수렴시킴). 빈 배열이면 inArray가 유효하지 않은 SQL을 만들 수 있어 조회 자체를 건너뜀.
    if (partnerEggIds.length === 0) return [];
    return tx
      .select({
        id: userEggs.id,
        distanceAccumulatedMeters: userEggs.distanceAccumulatedMeters,
        targetDistanceMeters: userEggs.targetDistanceMeters,
      })
      .from(userEggs)
      .where(activePartnerFilter);
  });

  if (result === null) {
    return Response.json({ error: "사용자를 찾을 수 없음" }, { status: 404 });
  }
  return Response.json({ eggs: result });
}
