// 마커 탭 시 "좌표 중복(같은 건물 내 여러 매장)" 리스트 조회 — Document/temp.md "관광지 마커 — 좌표 중복"
// 결정 배경. 반경을 요청 시점에 계산하지 않고, dedup 배치(scripts/tour-sync/dedupe-spots.ts)가
// 미리 써둔 representative_spot_id를 그대로 동등 비교만 함(id는 탭한 마커, 즉 대표 spot의 id).
//
// 항목 수가 DUPLICATE_SPOT_LIST_FILTER_THRESHOLD를 넘으면 spots를 비워서 반환 — 클라이언트가
// byContentType으로 카테고리 버튼만 그리고, ?contentTypeId=로 필터링해서 다시 요청해야 실제 항목이 옴.
import { and, eq, sql } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { tourismSpots } from "@/db/schema";
import { DUPLICATE_SPOT_LIST_FILTER_THRESHOLD } from "@/lib/game-config";

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const representativeId = Number(id);
  if (Number.isNaN(representativeId)) {
    return Response.json({ error: "잘못된 id" }, { status: 400 });
  }

  const contentTypeIdParam = request.nextUrl.searchParams.get("contentTypeId");
  const contentTypeId = contentTypeIdParam != null ? Number(contentTypeIdParam) : null;
  if (contentTypeIdParam != null && Number.isNaN(contentTypeId)) {
    return Response.json({ error: "잘못된 contentTypeId" }, { status: 400 });
  }

  const byContentType = await db
    .select({
      contentTypeId: tourismSpots.contentTypeId,
      count: sql<number>`COUNT(*)::int`,
    })
    .from(tourismSpots)
    .where(
      and(
        eq(tourismSpots.representativeSpotId, representativeId),
        eq(tourismSpots.isActive, true),
      ),
    )
    .groupBy(tourismSpots.contentTypeId);

  const totalCount = byContentType.reduce((sum, row) => sum + row.count, 0);
  if (totalCount === 0) {
    return Response.json({ error: "해당 관광지를 찾을 수 없음" }, { status: 404 });
  }

  const shouldReturnSpots = contentTypeId != null || totalCount <= DUPLICATE_SPOT_LIST_FILTER_THRESHOLD;

  const spots = shouldReturnSpots
    ? await db
        .select({
          id: tourismSpots.id,
          contentId: tourismSpots.contentId,
          title: tourismSpots.title,
          titleEn: tourismSpots.titleEn,
          firstImage: tourismSpots.firstImage,
          addr1: tourismSpots.addr1,
          addr2: tourismSpots.addr2,
          contentTypeId: tourismSpots.contentTypeId,
          cpyrhtDivCd: tourismSpots.cpyrhtDivCd,
          lat: sql<number>`ST_Y(${tourismSpots.locationGeog}::geometry)`,
          lng: sql<number>`ST_X(${tourismSpots.locationGeog}::geometry)`,
        })
        .from(tourismSpots)
        .where(
          and(
            eq(tourismSpots.representativeSpotId, representativeId),
            eq(tourismSpots.isActive, true),
            contentTypeId != null ? eq(tourismSpots.contentTypeId, contentTypeId) : undefined,
          ),
        )
        .orderBy(sql`${tourismSpots.contentId}::bigint ASC`)
    : [];

  return Response.json({ totalCount, byContentType, spots });
}
