// 90일 지난 미소진 egg_vouchers 정리 — scripts/cleanup-egg-vouchers.ts(수동 CLI)와
// instrumentation.ts 스케줄러가 공유하는 핵심 로직. process.exit()는 호출부(CLI 래퍼) 책임이라
// 여긴 순수 함수로 둠 — 안 그러면 스케줄러로 부를 때 Next.js 서버 프로세스 자체가 죽는다.
//
// ⚠️ 이 TTL은 회원(user_eggs)에는 적용 안 함 — egg_vouchers만 대상(init_plan.md DB 스키마 섹션 참고).
import { lt, sql } from "drizzle-orm";
import { db } from "../db";
import { eggVouchers } from "../db/schema";
import { GUEST_EGG_SHELF_LIFE_DAYS } from "./game-config";

export async function cleanupExpiredEggVouchers(): Promise<number> {
  const cutoff = sql`now() - interval '${sql.raw(String(GUEST_EGG_SHELF_LIFE_DAYS))} days'`;
  const deleted = await db.delete(eggVouchers).where(lt(eggVouchers.issuedAt, cutoff)).returning({
    id: eggVouchers.id,
  });
  return deleted.length;
}
