// 6단계 Phase 4 — 90일 지난 미소진 egg_vouchers 정리 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
// 게스트가 알만 받고 회원가입/부화 없이 이탈하면 voucher row가 영구히 안 지워지는 유령 데이터
// 문제를 막는 배치. 수동 실행: npm run vouchers:cleanup — tour-sync/sync.ts와 동일하게
// 아직 크론 인프라가 없는 개발 단계라 독립 스크립트로 둠(실제 스케줄링은 Document/plan/later.md의
// "TourAPI 배치 동기화 스케줄링"과 같은 문제라 그때 고를 스케줄러에 같이 얹으면 됨).
//
// ⚠️ 이 TTL은 회원(user_eggs)에는 적용 안 함 — egg_vouchers만 대상(init_plan.md DB 스키마 섹션 참고).
import "dotenv/config";
import { lt, sql } from "drizzle-orm";
import { db } from "../src/db";
import { eggVouchers } from "../src/db/schema";

const TTL_DAYS = 90;

async function main() {
  const cutoff = sql`now() - interval '${sql.raw(String(TTL_DAYS))} days'`;
  const deleted = await db.delete(eggVouchers).where(lt(eggVouchers.issuedAt, cutoff)).returning({
    id: eggVouchers.id,
  });
  console.log(`egg_vouchers 정리 완료 — ${TTL_DAYS}일 지난 미소진 row ${deleted.length}건 삭제`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
