// 6단계 — 로그인한 사용자의 TourMon 프로필 조회. AS의 sub(UUID) 기준으로 조회하며, 아직 온보딩
// (닉네임 입력, POST /api/auth/profile)을 안 거친 사용자는 404로 알려준다(connect_manual.md §5 패턴).
import { eq } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { users } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";

export async function GET(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }

  const [profile] = await db.select().from(users).where(eq(users.id, auth.sub));

  if (!profile) {
    return Response.json({ needsOnboarding: true }, { status: 404 });
  }

  return Response.json({
    id: profile.id,
    nickname: profile.nickname,
    createdAt: profile.createdAt,
    lastSyncedAt: profile.lastSyncedAt,
  });
}
