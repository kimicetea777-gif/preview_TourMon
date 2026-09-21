import { eq } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { appNotices } from "@/db/schema";
import { ADMIN_BASE_URL, requireAdminSession } from "@/lib/admin/server-session";
import { fetchCurrentAndroidConfig, publishAppNotice } from "@/lib/notice-publish";

function redirectToList(origin: string, params: Record<string, string>): Response {
  const url = new URL("/admin/notices", origin);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return Response.redirect(url, 303);
}

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  const auth = await requireAdminSession();
  if (!auth) return Response.json({ error: "관리자 권한 필요" }, { status: 403 });

  const origin = ADMIN_BASE_URL;
  const { id } = await context.params;
  const noticeId = Number(id);
  if (!Number.isInteger(noticeId)) {
    return redirectToList(origin, { error: "invalid_id" });
  }

  // app_notice_translations는 onDelete: "cascade"라 같이 지워짐.
  await db.delete(appNotices).where(eq(appNotices.id, noticeId));

  try {
    const android = await fetchCurrentAndroidConfig();
    await publishAppNotice(android);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return redirectToList(origin, { error: "publish_failed", detail: message.slice(0, 200) });
  }

  return redirectToList(origin, { success: "deleted" });
}
