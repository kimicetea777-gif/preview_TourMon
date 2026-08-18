// 클라이언트 로컬 캐싱(Document/temp.md "tour_spot 로컬 캐싱") — 활성 관광지 전체를 한 번에 내려줌.
// 대표(is_representative)뿐 아니라 좌표 중복 그룹의 멤버 전원을 포함해야, 클라이언트가 멤버 목록
// (기존 GET /api/tourism-spots/[id]/members 역할)까지 네트워크 없이 로컬에서 재현할 수 있음.
//
// 서버 응답 자체를 인메모리 TTL로 캐싱 — GET /api/monsters/config와 동일한 패턴(관리자 API가 없어
// 무효화 트리거가 없으므로 짧은 TTL로 자체 만료). tour:sync/tour:dedupe-spots 배치가 드물게(수동/
// 크론) 도는 데이터라, 클라이언트가 재요청할 때마다 PostGIS 좌표 추출 쿼리를 1만 row에 대해 다시
// 돌릴 필요 없음.
//
// ⚠️ 응답을 직접 gzip: Next.js(16.3.1 기준)의 기본 압축 미들웨어는 정적 페이지에만 적용되고
// App Router Route Handler(`route.ts`)의 응답은 압축을 안 함(`next start` 프로덕션 모드로 직접
// 확인함, 2026-08-18) — 이 라우트는 응답이 ~4MB로 커서 압축 없이는 매 다운로드마다 모바일
// 데이터/대역폭 낭비가 커짐. 압축도 캐시 갱신 시점에 한 번만 계산해서 요청마다 재압축하지 않음.
import { gzipSync } from "node:zlib";
import { sql } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { tourismSpots } from "@/db/schema";

const CACHE_TTL_MS = 60 * 60 * 1000;

let cache: { json: string; gzipped: Buffer; expiresAt: number } | null = null;

async function loadBulkSpots(): Promise<string> {
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
      representativeSpotId: tourismSpots.representativeSpotId,
      isRepresentative: tourismSpots.isRepresentative,
      memberCount: tourismSpots.memberCount,
      lat: sql<number>`ST_Y(${tourismSpots.locationGeog}::geometry)`,
      lng: sql<number>`ST_X(${tourismSpots.locationGeog}::geometry)`,
    })
    .from(tourismSpots)
    .where(sql`${tourismSpots.isActive} = true`);

  return JSON.stringify({ spots: rows });
}

export async function GET(request: NextRequest) {
  const now = Date.now();
  if (!cache || cache.expiresAt < now) {
    const json = await loadBulkSpots();
    cache = { json, gzipped: gzipSync(json), expiresAt: now + CACHE_TTL_MS };
  }

  const acceptsGzip = request.headers.get("accept-encoding")?.includes("gzip") ?? false;
  if (!acceptsGzip) {
    return new Response(cache.json, {
      headers: { "Content-Type": "application/json" },
    });
  }
  return new Response(new Uint8Array(cache.gzipped), {
    headers: {
      "Content-Type": "application/json",
      "Content-Encoding": "gzip",
      "Vary": "Accept-Encoding",
    },
  });
}
