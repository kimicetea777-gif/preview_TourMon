// 6단계 — 로그인 직후 온보딩(닉네임 입력)에서 TourMon 프로필 row를 생성/수정.
// AS는 email/password/role만 책임지고 닉네임 같은 서비스 고유 정보는 TourMon이 직접 관리한다
// (connect_manual.md §5, init_plan.md 4-1 "사용자 프로필 조회/수정").
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { users } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";

const NICKNAME_MAX_LENGTH = 30;

export async function POST(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const nickname = typeof body?.nickname === "string" ? body.nickname.trim() : "";

  if (!nickname || nickname.length > NICKNAME_MAX_LENGTH) {
    return Response.json(
      { error: `nickname은 1~${NICKNAME_MAX_LENGTH}자여야 함` },
      { status: 400 },
    );
  }

  const [profile] = await db
    .insert(users)
    .values({ id: auth.sub, nickname })
    .onConflictDoUpdate({ target: users.id, set: { nickname } })
    .returning();

  return Response.json({
    id: profile.id,
    nickname: profile.nickname,
    createdAt: profile.createdAt,
    lastSyncedAt: profile.lastSyncedAt,
  });
}
