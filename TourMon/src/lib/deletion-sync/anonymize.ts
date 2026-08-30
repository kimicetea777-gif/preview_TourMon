// §6 파기 파이프라인의 실제 anonymize 동작.
//
// 2026-08-30 변경 — 예전엔 users row를 남긴 채 nickname만 placeholder로 덮어썼는데(가명처리),
// id(= AS sub)가 그대로 남아 재식별 가능한 상태였다. 이제는 이용자 식별 정보를 실제로 없앤다:
//   1) user_eggs/user_monsters의 user_id를 공용 익명 버킷으로 재지정 — 개별 row는 남겨
//      (관광지별/종별 부화 분포 같은) 전역 통계에 계속 쓰되, 특정 개인과의 연결은 끊는다.
//      모든 탈퇴 유저의 기록이 이 한 id로 모이므로 "누구 것인지"도 "탈퇴 유저가 몇 명인지"도 복원 불가.
//   2) 원래 users row는 하드 삭제 — id/닉네임/탈퇴 시각 등 이용자 식별 정보를 통째로 제거.
// user_id FK가 onDelete:"cascade"라 (2)를 (1)보다 먼저 하면 게임 기록이 같이 지워지므로 순서 고정.
import { eq } from "drizzle-orm";
import { db } from "../../db";
import { userEggs, userMonsters, users } from "../../db/schema";

// 탈퇴 유저의 게임 기록을 옮겨 붙일 공용 익명 버킷 유저. 고정 UUID(전부 0) — seed 없이 첫 탈퇴
// 확정 시점에 lazy insert(ON CONFLICT DO NOTHING)로 만들어진다.
const ANONYMIZED_BUCKET_USER_ID = "00000000-0000-0000-0000-000000000000";
const ANONYMIZED_BUCKET_NICKNAME = "탈퇴한 사용자";

// idempotent — deleted-users/membership-events 두 스트림이 같은 유저를 중복으로 가리키거나 재시도로
// 같은 아이템이 다시 처리돼도 안전해야 한다. 이미 처리된 유저는 users row가 없으므로 조용히 반환.
export async function anonymizeUser(userId: string): Promise<void> {
  if (userId === ANONYMIZED_BUCKET_USER_ID) return; // 버킷 자신은 대상 아님

  await db.transaction(async (tx) => {
    const [user] = await tx.select().from(users).where(eq(users.id, userId)).limit(1);
    if (!user) return;

    await tx
      .insert(users)
      .values({ id: ANONYMIZED_BUCKET_USER_ID, nickname: ANONYMIZED_BUCKET_NICKNAME })
      .onConflictDoNothing({ target: users.id });

    await tx
      .update(userEggs)
      .set({ userId: ANONYMIZED_BUCKET_USER_ID })
      .where(eq(userEggs.userId, userId));
    await tx
      .update(userMonsters)
      .set({ userId: ANONYMIZED_BUCKET_USER_ID })
      .where(eq(userMonsters.userId, userId));

    await tx.delete(users).where(eq(users.id, userId));
  });
}
