// 2단계: TourAPI 관광지 데이터 배치 동기화 (areaBasedSyncList2, 국문만).
// 수동 실행: npm run tour:sync — 아직 인증/크론 인프라가 없는 개발 단계라 map-pipeline과 동일하게
// 스크립트 방식으로 둠. 상세 결정 배경: Document/init_plan.md 2단계, Document/tour_api_detail.md.
//
// ⚠️ 영문(EngService2) 배치 수집은 하지 않음 — KorService2/EngService2가 content_id를 공유한다는
// 문서 전제(init_plan.md 4-7 섹션)가 실제로는 틀렸음을 확인함(예: 경복궁 content_id=126508은
// KorService2에만 존재, EngService2에는 없음 — 두 서비스가 서로 다른 ID 체계를 씀). 좌표/제목 기반
// 퍼지 매칭 등 재설계가 필요해서 7단계(다국어)로 연기 — title_en/addr1_en/addr2_en은 현재 null.
import "dotenv/config";
import { eq, sql } from "drizzle-orm";
import { db } from "../../src/db";
import { regions, tourismSpots } from "../../src/db/schema";
import {
  fetchAreaBasedSyncList,
  fetchLdongCode,
  type AreaBasedSyncItem,
} from "../../src/lib/tour-api";
import { CALL_BUDGET_WARNING_THRESHOLD, NUM_OF_ROWS } from "./config";

let callCount = 0;
let budgetWarned = false;

function trackCall() {
  callCount += 1;
  if (!budgetWarned && callCount >= CALL_BUDGET_WARNING_THRESHOLD) {
    budgetWarned = true;
    console.warn(
      `⚠️ TourAPI 호출 수가 ${callCount}회 — 일일 1,000회 한도에 근접함`,
    );
  }
}

function toYyyymmdd(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

async function getModifiedSinceCutoff(): Promise<string | undefined> {
  const [row] = await db
    .select({ maxSyncedAt: sql<Date | null>`max(${tourismSpots.syncedAt})` })
    .from(tourismSpots);
  if (!row?.maxSyncedAt) return undefined;
  return toYyyymmdd(new Date(row.maxSyncedAt));
}

async function fetchAllPages(params: {
  service: "kor" | "eng";
  lDongRegnCd: string;
  lDongSignguCd: string;
  modifiedtime?: string;
}): Promise<AreaBasedSyncItem[]> {
  const first = await fetchAreaBasedSyncList({
    ...params,
    pageNo: 1,
    numOfRows: NUM_OF_ROWS,
  });
  trackCall();

  const items = [...first.items];
  const totalPages = Math.ceil(first.totalCount / NUM_OF_ROWS);
  for (let pageNo = 2; pageNo <= totalPages; pageNo++) {
    const page = await fetchAreaBasedSyncList({
      ...params,
      pageNo,
      numOfRows: NUM_OF_ROWS,
    });
    trackCall();
    items.push(...page.items);
  }
  return items;
}

async function upsertKorItems(items: AreaBasedSyncItem[], regionCode: string) {
  let skippedNoCoords = 0;
  for (const item of items) {
    const lng = Number(item.mapx);
    const lat = Number(item.mapy);
    if (!item.mapx || !item.mapy || Number.isNaN(lng) || Number.isNaN(lat)) {
      skippedNoCoords++;
      continue;
    }
    const shared = {
      title: item.title,
      addr1: item.addr1 || null,
      addr2: item.addr2 || null,
      tel: item.tel || null,
      locationGeog: `POINT(${item.mapx} ${item.mapy})`,
      contentTypeId: Number(item.contenttypeid),
      firstImage: item.firstimage || null,
      cpyrhtDivCd: item.cpyrhtDivCd || null,
      isActive: item.showflag !== "0",
      syncedAt: new Date(),
    };
    await db
      .insert(tourismSpots)
      .values({ contentId: item.contentid, regionCode, ...shared })
      .onConflictDoUpdate({
        target: tourismSpots.contentId,
        set: shared,
      });
  }
  if (skippedNoCoords > 0) {
    console.log(`    (좌표 누락으로 스킵: ${skippedNoCoords}건)`);
  }
}

async function main() {
  const enabledRegions = await db
    .select()
    .from(regions)
    .where(eq(regions.isEnabled, true));

  const modifiedtime = await getModifiedSinceCutoff();
  console.log(
    modifiedtime
      ? `증분 동기화 기준일(modifiedtime): ${modifiedtime}`
      : "첫 동기화 — modifiedtime 없이 전체 수집",
  );

  for (const region of enabledRegions) {
    console.log(`\n[${region.name}] 시군구 코드 조회 중...`);
    const { items: signguList } = await fetchLdongCode({
      service: "kor",
      lDongRegnCd: region.code,
    });
    trackCall();
    console.log(`[${region.name}] 시군구 ${signguList.length}개`);

    for (const signgu of signguList) {
      console.log(`  - ${region.name} ${signgu.name}(${signgu.code}) 국문 수집 중...`);
      const korItems = await fetchAllPages({
        service: "kor",
        lDongRegnCd: region.code,
        lDongSignguCd: signgu.code,
        modifiedtime,
      });
      await upsertKorItems(korItems, region.code);
      console.log(`    -> ${korItems.length}건 upsert 완료`);
    }
  }

  console.log(`\n동기화 완료 — 총 TourAPI 호출 ${callCount}회`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
