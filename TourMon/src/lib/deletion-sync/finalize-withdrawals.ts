// 32일 유예가 지난 탈퇴 신청을 최종 anonymize — AS 쪽 실제 유예기간(30일, BatchPolicy.java) + 2일
// 버퍼(Document/temp.md §6-6 결정, TypeButter와 동일 원칙: AS가 자기 유예를 끝내고 정리하는 시점과
// TourMon의 최종 처리가 겹치지 않게 함).
//
// anonymizeUser는 users row를 하드 삭제하므로(2026-08-30, anonymize.ts 참고) 처리된 유저는 아래
// 조회(membership_withdrawn_at 있는 row)에서 자연히 빠진다.
import { and, isNotNull, lt } from "drizzle-orm";
import { db } from "../../db";
import { users } from "../../db/schema";
import { anonymizeUser } from "./anonymize";

const GRACE_PERIOD_DAYS = 32;

export async function finalizeExpiredWithdrawals(): Promise<void> {
  const cutoff = new Date(Date.now() - GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000);
  const targets = await db
    .select({ id: users.id })
    .from(users)
    .where(
      and(
        isNotNull(users.membershipWithdrawnAt),
        lt(users.membershipWithdrawnAt, cutoff),
      ),
    );

  for (const { id } of targets) {
    try {
      await anonymizeUser(id);
    } catch (e) {
      console.error("[deletion-sync] finalize 실패, 다음 유저로 계속:", id, e);
    }
  }
}
