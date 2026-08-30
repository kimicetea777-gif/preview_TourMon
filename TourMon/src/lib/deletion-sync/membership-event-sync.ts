// 멤버십 상태 변경(연결 해제/밴/밴 해제) 폴링(8-4). CLIENT_WITHDRAWN은 32일 유예를 시작시키기만
// 하고(즉시 anonymize 아님), 실제 파기는 finalize-withdrawals.ts가 유예 종료 후 처리한다.
import { and, eq, isNull } from "drizzle-orm";
import { db } from "../../db";
import { users } from "../../db/schema";
import { DELETION_SYNC_PAGE_LIMIT, pollMembershipEvents, type MembershipEvent } from "./poll-clients";
import { loadCursor, advanceCursor } from "./cursor-repository";

const POLLER_NAME = "membership-events" as const;

export async function syncMembershipEvents(): Promise<void> {
  let mayHaveMore = true;
  while (mayHaveMore) {
    mayHaveMore = await syncOnePage();
  }
}

async function syncOnePage(): Promise<boolean> {
  const cursor = await loadCursor(POLLER_NAME);

  let items;
  try {
    items = await pollMembershipEvents(cursor.sinceTimestamp, cursor.sinceId);
  } catch (e) {
    console.error("[deletion-sync] membership-events 폴링 실패:", e);
    return false;
  }

  for (const item of items) {
    try {
      await processItem(item);
    } catch (e) {
      console.error("[deletion-sync] membership-events 처리 실패, 여기서 중단:", item, e);
      return false;
    }
    await advanceCursor(POLLER_NAME, {
      sinceTimestamp: new Date(item.changedAt),
      sinceId: item.id,
    });
  }

  return items.length === DELETION_SYNC_PAGE_LIMIT;
}

async function processItem(item: MembershipEvent): Promise<void> {
  switch (item.type) {
    case "CLIENT_WITHDRAWN":
      // 이미 파기됐거나(anonymize가 users row를 하드 삭제 → 아래 update가 0 rows) 이미 유예가
      // 시작돼있으면(membershipWithdrawnAt) 그대로 둠 — 최초 이벤트의 시각을 유지해야 유예기간
      // 계산이 재이벤트로 밀리지 않는다.
      await db
        .update(users)
        .set({ membershipWithdrawnAt: new Date(item.changedAt) })
        .where(
          and(eq(users.id, item.userId), isNull(users.membershipWithdrawnAt)),
        );
      break;
    case "CLIENT_ACTIVATED":
      // 재연결 구제 — 유예 중이던 유저를 정상으로 복원. 이미 파기된 유저는 users row 자체가 없어
      // (anonymize가 하드 삭제) 아래 update가 0 rows라 자연히 대상에서 빠짐.
      await db
        .update(users)
        .set({ membershipWithdrawnAt: null })
        .where(eq(users.id, item.userId));
      break;
    case "CLIENT_BANNED":
      // 밴은 이탈이 아니므로 anonymize 트리거 아님 — TourMon엔 별도 밴 상태 자체가 없어 로그만 남김
      // (TypeButter 참고 구현과 동일 원칙, Document/temp.md §6 참고).
      console.log("[deletion-sync] CLIENT_BANNED 이벤트 수신(별도 처리 없음):", item.userId);
      break;
  }
}
