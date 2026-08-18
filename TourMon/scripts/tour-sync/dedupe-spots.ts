// 좌표 중복(같은 건물 내 여러 매장) 그룹핑 배치 — 요청 시점이 아니라 동기화 시점에 한 번만 계산
// (Document/temp.md "관광지 마커 — 좌표 중복" 결정 배경 참고). tour:sync 이후에 실행해서 모든 활성 spot의
// representative_spot_id/is_representative를 다시 채움 — 재실행해도 안전(항상 전체 재계산, 증분 아님).
//
// 그룹핑: ST_ClusterDBSCAN(eps=5m, minpoints=1)로 연결 성분을 구함. eps는 반드시 미터 단위 좌표계
// (ST_Transform(..., 3857))에 적용해야 함 — location_geog를 geometry로 캐스트만 하고 변환을 빼먹으면
// eps가 도(degree) 단위로 해석돼 전체가 한 덩어리로 묶이는 버그가 남(실측 중 실제로 겪음).
//
// 대표 선정: representative_priority가 있으면 그중 최댓값 우선, 없으면 content_id 최솟값.
// content_id는 text 컬럼이라 그냥 비교하면 자릿수가 다른 값끼리 사전식으로 잘못 정렬됨
// (예: "1000000" < "999999" 텍스트 비교, 실제로는 반대) — bigint로 캐스트해서 비교함.
//
// 실행: npm run tour:dedupe-spots -- --dry-run (DB 변경 없이 통계만) / npm run tour:dedupe-spots
import "dotenv/config";
import { sql } from "drizzle-orm";
import { db } from "../../src/db";
import { DUPLICATE_SPOT_GROUP_RADIUS_METERS } from "./config";

const DRY_RUN = process.argv.includes("--dry-run");

async function main() {
  console.log(DRY_RUN ? "=== dry-run 모드 (UPDATE 없음) ===" : "=== 실행 모드 ===");
  console.log(`그룹핑 반경: ${DUPLICATE_SPOT_GROUP_RADIUS_METERS}m`);

  const [{ clusterCount, multiMemberClusterCount, maxClusterSize }] = await db.execute<{
    clusterCount: number;
    multiMemberClusterCount: number;
    maxClusterSize: number;
  }>(sql`
    WITH clustered AS (
      SELECT id,
        ST_ClusterDBSCAN(
          ST_Transform(location_geog::geometry, 3857),
          eps := ${DUPLICATE_SPOT_GROUP_RADIUS_METERS},
          minpoints := 1
        ) OVER () AS cluster_id
      FROM tourism_spots
      WHERE is_active = true
    ),
    cluster_sizes AS (
      SELECT cluster_id, COUNT(*) AS member_count
      FROM clustered
      GROUP BY cluster_id
    )
    SELECT
      COUNT(*)::int AS "clusterCount",
      COUNT(*) FILTER (WHERE member_count > 1)::int AS "multiMemberClusterCount",
      MAX(member_count)::int AS "maxClusterSize"
    FROM cluster_sizes;
  `);

  console.log(
    `클러스터 총 ${clusterCount}개 (중복 없는 solo 포함), 그중 중복 그룹 ${multiMemberClusterCount}개, 최대 규모 ${maxClusterSize}`,
  );

  if (DRY_RUN) {
    console.log("dry-run이라 DB는 변경되지 않음 — 통계 확인 후 --dry-run 없이 재실행할 것.");
    return;
  }

  const result = await db.execute(sql`
    WITH clustered AS (
      SELECT id, content_id, representative_priority,
        ST_ClusterDBSCAN(
          ST_Transform(location_geog::geometry, 3857),
          eps := ${DUPLICATE_SPOT_GROUP_RADIUS_METERS},
          minpoints := 1
        ) OVER () AS cluster_id
      FROM tourism_spots
      WHERE is_active = true
    ),
    cluster_sizes AS (
      SELECT cluster_id, COUNT(*) AS member_count
      FROM clustered
      GROUP BY cluster_id
    ),
    representatives AS (
      SELECT DISTINCT ON (cluster_id) cluster_id, id AS representative_id
      FROM clustered
      ORDER BY cluster_id, representative_priority DESC NULLS LAST, content_id::bigint ASC
    )
    UPDATE tourism_spots t
    SET
      representative_spot_id = r.representative_id,
      is_representative = (t.id = r.representative_id),
      member_count = s.member_count
    FROM clustered c
    JOIN representatives r ON r.cluster_id = c.cluster_id
    JOIN cluster_sizes s ON s.cluster_id = c.cluster_id
    WHERE t.id = c.id;
  `);

  console.log(`${result.count ?? 0}개 row에 representative_spot_id/is_representative 적용 완료.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
