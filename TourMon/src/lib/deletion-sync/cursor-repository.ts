// polling_cursors 테이블 read/advance — deleted-users/membership-events 두 스트림은 서로 독립된
// 시퀀스라 커서를 절대 공유하면 안 됨(pollerName으로 구분, TypeButter 참고 구현과 동일 원칙).
import { eq } from "drizzle-orm";
import { db } from "../../db";
import { pollingCursors } from "../../db/schema";

export type PollerName = "deleted-users" | "membership-events";

export type Cursor = { sinceTimestamp: Date; sinceId: number | null };

const EPOCH = new Date(0);

export async function loadCursor(pollerName: PollerName): Promise<Cursor> {
  const [row] = await db
    .select()
    .from(pollingCursors)
    .where(eq(pollingCursors.pollerName, pollerName))
    .limit(1);
  if (!row) return { sinceTimestamp: EPOCH, sinceId: null };
  return { sinceTimestamp: row.sinceTimestamp, sinceId: row.sinceId };
}

export async function advanceCursor(pollerName: PollerName, cursor: Cursor): Promise<void> {
  await db
    .insert(pollingCursors)
    .values({
      pollerName,
      sinceTimestamp: cursor.sinceTimestamp,
      sinceId: cursor.sinceId,
      updatedAt: new Date(),
    })
    .onConflictDoUpdate({
      target: pollingCursors.pollerName,
      set: {
        sinceTimestamp: cursor.sinceTimestamp,
        sinceId: cursor.sinceId,
        updatedAt: new Date(),
      },
    });
}
