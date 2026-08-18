// 7단계 — 국문/영문 TourAPI 서비스 좌표 매칭 재설계 + 백필 (init_plan.md 4-7 섹션).
// KorService2/EngService2는 서로 다른 content_id 체계를 씀(sync.ts 상단 주석 참고) — 그래서 새
// row를 만드는 게 아니라, 영문 서비스를 배치 조회해서 좌표로 기존 국문 tourism_spots row를 찾아
// title_en/addr1_en/addr2_en/content_id_en만 UPDATE함.
//
// 매칭 순서: ① 좌표 완전 일치(ENG_MATCH_EXACT_TOLERANCE_METERS) 반경 안 후보 조회 → 없으면
// ② 반경(ENG_MATCH_FALLBACK_RADIUS_METERS) 안 후보 조회 → 각 단계에서 content_types.foreign_code로
// 국문 코드 역매칭해서 content_type이 호환되는 후보만 남김.
// ⚠️ 실제 데이터로 돌려보니 국문 tourism_spots 자체에 좌표가 겹치는 row가 많음(쇼핑몰/푸드코트 등
// 한 건물에 여러 매장) — 그래서 "가장 가까운 1건"을 그냥 고르면 엉뚱한 매장에 매칭될 위험이 있음.
// 그래서 필터링 후 후보가 정확히 1건일 때만 자동 UPDATE, 0건이면 미매칭으로 스킵, 2건 이상이면
// "애매함"으로 engMatchReviews 테이블에 후보 목록과 함께 적재(자동 판단 안 함, 관리자 페이지가
// 생기면 수동으로 고르는 용도 — 그 UPDATE 로직 자체는 이번 스코프 밖).
//
// 실행: npm run tour:eng-match -- --dry-run (DB 변경 없이 통계만) / npm run tour:eng-match (실행)
import "dotenv/config";
import { eq, sql } from "drizzle-orm";
import { db } from "../../src/db";
import { contentTypes, engMatchReviews, regions, tourismSpots } from "../../src/db/schema";
import {
  fetchAreaBasedSyncList,
  fetchLdongCode,
  type AreaBasedSyncItem,
} from "../../src/lib/tour-api";
import {
  CALL_BUDGET_WARNING_THRESHOLD,
  ENG_MATCH_EXACT_TOLERANCE_METERS,
  ENG_MATCH_FALLBACK_RADIUS_METERS,
  NUM_OF_ROWS,
} from "./config";

const DRY_RUN = process.argv.includes("--dry-run");

let callCount = 0;
let budgetWarned = false;

function trackCall() {
  callCount += 1;
  if (!budgetWarned && callCount >= CALL_BUDGET_WARNING_THRESHOLD) {
    budgetWarned = true;
    console.warn(`⚠️ TourAPI 호출 수가 ${callCount}회 — 일일 1,000회 한도에 근접함`);
  }
}

async function fetchAllEngPages(params: {
  lDongRegnCd: string;
  lDongSignguCd: string;
}): Promise<AreaBasedSyncItem[]> {
  const first = await fetchAreaBasedSyncList({
    service: "eng",
    ...params,
    pageNo: 1,
    numOfRows: NUM_OF_ROWS,
  });
  trackCall();

  const items = [...first.items];
  const totalPages = Math.ceil(first.totalCount / NUM_OF_ROWS);
  for (let pageNo = 2; pageNo <= totalPages; pageNo++) {
    const page = await fetchAreaBasedSyncList({
      service: "eng",
      ...params,
      pageNo,
      numOfRows: NUM_OF_ROWS,
    });
    trackCall();
    items.push(...page.items);
  }
  return items;
}

interface KorCandidate {
  id: number;
  contentTypeId: number;
}

// 반경 안의 모든 국문 후보(필터링 전 원본) — 좌표가 겹치는 row가 많아서 1건만 뽑으면 안 됨.
async function findKorSpotsWithin(lng: number, lat: number, radiusMeters: number): Promise<KorCandidate[]> {
  const point = sql`ST_MakePoint(${lng}, ${lat})::geography`;
  return db
    .select({ id: tourismSpots.id, contentTypeId: tourismSpots.contentTypeId })
    .from(tourismSpots)
    .where(sql`ST_DWithin(${tourismSpots.locationGeog}, ${point}, ${radiusMeters})`);
}

interface Stats {
  exactMatched: number;
  fallbackMatched: number;
  ambiguousQueued: number;
  contentTypeFilteredAll: number; // 좌표 후보는 있었지만 content_type 호환 후보가 0건
  unmatched: number; // 좌표 후보 자체가 없음(영문에만 존재)
  skippedNoCoords: number;
}

async function matchEngItems(
  items: AreaBasedSyncItem[],
  foreignToKorContentType: Map<number, number>,
  stats: Stats,
) {
  for (const item of items) {
    const lng = Number(item.mapx);
    const lat = Number(item.mapy);
    if (!item.mapx || !item.mapy || Number.isNaN(lng) || Number.isNaN(lat)) {
      stats.skippedNoCoords++;
      continue;
    }

    const expectedKorContentType = foreignToKorContentType.get(Number(item.contenttypeid));

    let raw = await findKorSpotsWithin(lng, lat, ENG_MATCH_EXACT_TOLERANCE_METERS);
    let tier: "exact" | "fallback" = "exact";
    let filtered = raw.filter((c) => c.contentTypeId === expectedKorContentType);

    if (raw.length === 0) {
      raw = await findKorSpotsWithin(lng, lat, ENG_MATCH_FALLBACK_RADIUS_METERS);
      tier = "fallback";
      filtered = raw.filter((c) => c.contentTypeId === expectedKorContentType);
    }

    if (raw.length === 0) {
      stats.unmatched++;
      continue;
    }
    if (filtered.length === 0) {
      stats.contentTypeFilteredAll++;
      continue;
    }
    if (filtered.length > 1) {
      stats.ambiguousQueued++;
      if (!DRY_RUN) {
        await db
          .insert(engMatchReviews)
          .values({
            contentIdEn: item.contentid,
            titleEn: item.title,
            addr1En: item.addr1 || null,
            addr2En: item.addr2 || null,
            locationGeog: `POINT(${lng} ${lat})`,
            contentTypeId: expectedKorContentType ?? null,
            candidateTourismSpotIds: filtered.map((c) => c.id),
          })
          .onConflictDoNothing({ target: engMatchReviews.contentIdEn });
      }
      continue;
    }

    // 정확히 1건 — 자동 매칭
    if (tier === "exact") stats.exactMatched++;
    else stats.fallbackMatched++;

    if (!DRY_RUN) {
      await db
        .update(tourismSpots)
        .set({
          titleEn: item.title,
          addr1En: item.addr1 || null,
          addr2En: item.addr2 || null,
          contentIdEn: item.contentid,
        })
        .where(eq(tourismSpots.id, filtered[0].id));
    }
  }
}

async function main() {
  console.log(DRY_RUN ? "=== dry-run 모드 (UPDATE/적재 없음) ===" : "=== 실행 모드 ===");

  const contentTypeRows = await db.select().from(contentTypes);
  const foreignToKorContentType = new Map<number, number>();
  for (const row of contentTypeRows) {
    if (row.foreignCode != null) foreignToKorContentType.set(row.foreignCode, row.id);
  }

  const enabledRegions = await db.select().from(regions).where(eq(regions.isEnabled, true));

  const stats: Stats = {
    exactMatched: 0,
    fallbackMatched: 0,
    ambiguousQueued: 0,
    contentTypeFilteredAll: 0,
    unmatched: 0,
    skippedNoCoords: 0,
  };

  for (const region of enabledRegions) {
    console.log(`\n[${region.name}] 시군구 코드 조회 중(영문)...`);
    const { items: signguList } = await fetchLdongCode({ service: "eng", lDongRegnCd: region.code });
    trackCall();
    console.log(`[${region.name}] 시군구 ${signguList.length}개`);

    for (const signgu of signguList) {
      console.log(`  - ${region.name} ${signgu.name}(${signgu.code}) 영문 수집+매칭 중...`);
      const engItems = await fetchAllEngPages({
        lDongRegnCd: region.code,
        lDongSignguCd: signgu.code,
      });
      await matchEngItems(engItems, foreignToKorContentType, stats);
      console.log(`    -> ${engItems.length}건 처리`);
    }
  }

  console.log(`\n=== 매칭 결과 ===`);
  console.log(`완전 일치(자동 UPDATE): ${stats.exactMatched}`);
  console.log(`반경 매칭(자동 UPDATE): ${stats.fallbackMatched}`);
  console.log(`애매함(후보 2건 이상, 검토 대기열 적재): ${stats.ambiguousQueued}`);
  console.log(`좌표는 맞지만 호환되는 content_type 후보 없음: ${stats.contentTypeFilteredAll}`);
  console.log(`국문 매칭 실패(영문에만 존재, 스킵): ${stats.unmatched}`);
  console.log(`좌표 누락으로 스킵: ${stats.skippedNoCoords}`);
  console.log(`\nTourAPI 호출 ${callCount}회`);
  if (DRY_RUN) console.log("dry-run이라 DB는 변경되지 않음 — 통계 확인 후 --dry-run 없이 재실행할 것.");
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
