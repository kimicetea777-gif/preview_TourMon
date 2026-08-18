// 지도 마커 조회 — 뷰포트 bounding box 기준 (4-2 섹션). GIST 인덱스 활용을 위해 ST_Intersects 사용.
// 좌표 중복(같은 건물 내 여러 매장) 그룹의 대표만 반환 — is_representative는 dedup 배치
// (scripts/tour-sync/dedupe-spots.ts)가 동기화 시점에 미리 계산해둔 값. 묶인 나머지 항목들은
// GET /api/tourism-spots/[id]/members로 조회(Document/temp.md "관광지 마커 — 좌표 중복" 결정 배경).
import { sql } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { tourismSpots } from "@/db/schema";

export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;
  const minLon = Number(params.get("minLon"));
  const minLat = Number(params.get("minLat"));
  const maxLon = Number(params.get("maxLon"));
  const maxLat = Number(params.get("maxLat"));

  if ([minLon, minLat, maxLon, maxLat].some((v) => Number.isNaN(v))) {
    return Response.json(
      { error: "minLon, minLat, maxLon, maxLat 쿼리 파라미터가 모두 필요함" },
      { status: 400 },
    );
  }

  const envelope = sql`ST_MakeEnvelope(${minLon}, ${minLat}, ${maxLon}, ${maxLat}, 4326)::geography`;

  const rows = await db
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
      memberCount: tourismSpots.memberCount,
      lat: sql<number>`ST_Y(${tourismSpots.locationGeog}::geometry)`,
      lng: sql<number>`ST_X(${tourismSpots.locationGeog}::geometry)`,
    })
    .from(tourismSpots)
    .where(
      sql`${tourismSpots.isActive} = true AND ${tourismSpots.isRepresentative} = true AND ST_Intersects(${tourismSpots.locationGeog}, ${envelope})`,
    );

  return Response.json({ spots: rows });
}
