// AS 계정 자체가 하드 삭제됐을 때(8-3) — AS가 이미 자기 쪽 30일 유예를 다 거친 뒤에만 이 스트림에
// 올리므로, TourMon은 보자마자 즉시 anonymize한다(추가 유예 불필요).
import { DELETION_SYNC_PAGE_LIMIT, pollDeletedUsers } from "./poll-clients";
import { loadCursor, advanceCursor } from "./cursor-repository";
import { anonymizeUser } from "./anonymize";

const POLLER_NAME = "deleted-users" as const;

export async function syncDeletedUsers(): Promise<void> {
  let mayHaveMore = true;
  while (mayHaveMore) {
    mayHaveMore = await syncOnePage();
  }
}

// 커서는 페이지 끝이 아니라 아이템마다 커밋 — 중간에 실패해도 이미 처리한 만큼은 보존한다
// (TypeButter 참고 구현과 동일 원칙).
async function syncOnePage(): Promise<boolean> {
  const cursor = await loadCursor(POLLER_NAME);

  let items;
  try {
    items = await pollDeletedUsers(cursor.sinceTimestamp, cursor.sinceId);
  } catch (e) {
    console.error("[deletion-sync] deleted-users 폴링 실패:", e);
    return false;
  }

  for (const item of items) {
    try {
      await anonymizeUser(item.userId);
    } catch (e) {
      console.error("[deletion-sync] deleted-users 처리 실패, 여기서 중단:", item, e);
      return false;
    }
    await advanceCursor(POLLER_NAME, {
      sinceTimestamp: new Date(item.deletedAt),
      sinceId: item.id,
    });
  }

  return items.length === DELETION_SYNC_PAGE_LIMIT;
}
