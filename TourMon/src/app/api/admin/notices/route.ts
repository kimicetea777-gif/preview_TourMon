// 어드민 공지 추가 — 저장하면 바로 publishAppNotice()로 R2까지 게시된다(사용자 확인, 몬스터
// 추가/TourAPI 동기화 트리거와 동일하게 별도 "게시" 단계 없음).
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { appNoticeTranslations, appNotices, noticeLevelEnum } from "@/db/schema";
import { ADMIN_BASE_URL, requireAdminSession } from "@/lib/admin/server-session";
import { fetchCurrentAndroidConfig, publishAppNotice } from "@/lib/notice-publish";

function redirectToList(origin: string, params: Record<string, string>): Response {
  const url = new URL("/admin/notices", origin);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return Response.redirect(url, 303);
}

// 입력값 검증 에러는 add=1도 같이 실어 보내 목록 페이지가 "공지 추가" 팝업을 다시 열어둔 채로
// 에러를 보여준다(monsters와 동일한 패턴) — publish_failed는 이미 저장이 끝난 뒤라 팝업을 다시 열
// 필요가 없어서 이 헬퍼를 안 쓴다.
function redirectToListError(origin: string, error: string): Response {
  return redirectToList(origin, { error, add: "1" });
}

// datetime-local 입력값("YYYY-MM-DDTHH:mm", 초/타임존 없음)을 KST(+09:00)로 명시 해석한다 — 서버
// 프로세스의 OS 타임존(배포 컨테이너는 UTC일 수 있음)에 맡기면 9시간 어긋날 위험이 있어서 피한다.
// 반환값: 비어있으면 null(정상, 미입력) / 형식 오류면 undefined.
function parseOptionalKstDatetime(value: FormDataEntryValue | null): Date | null | undefined {
  const str = value?.toString().trim();
  if (!str) return null;
  const date = new Date(`${str}:00+09:00`);
  return Number.isNaN(date.getTime()) ? undefined : date;
}

export async function POST(request: NextRequest) {
  const auth = await requireAdminSession();
  if (!auth) return Response.json({ error: "관리자 권한 필요" }, { status: 403 });

  const origin = ADMIN_BASE_URL;
  const form = await request.formData();

  const level = form.get("level")?.toString();
  const urlRaw = form.get("url")?.toString().trim();
  const titleKo = form.get("titleKo")?.toString().trim();
  const bodyKo = form.get("bodyKo")?.toString().trim();
  const titleEn = form.get("titleEn")?.toString().trim();
  const bodyEn = form.get("bodyEn")?.toString().trim();

  if (!level || !(noticeLevelEnum.enumValues as readonly string[]).includes(level)) {
    return redirectToListError(origin, "invalid_level");
  }
  if (!titleKo || !bodyKo || !titleEn || !bodyEn) {
    return redirectToListError(origin, "text_required");
  }
  if (urlRaw && !urlRaw.startsWith("https://")) {
    return redirectToListError(origin, "invalid_url");
  }

  const startsAt = parseOptionalKstDatetime(form.get("startsAt"));
  const endsAt = parseOptionalKstDatetime(form.get("endsAt"));
  if (startsAt === undefined || endsAt === undefined) {
    return redirectToListError(origin, "invalid_date");
  }
  if (startsAt && endsAt && startsAt > endsAt) {
    return redirectToListError(origin, "date_range_invalid");
  }

  await db.transaction(async (tx) => {
    const [notice] = await tx
      .insert(appNotices)
      .values({
        level: level as (typeof noticeLevelEnum.enumValues)[number],
        startsAt,
        endsAt,
        url: urlRaw || null,
      })
      .returning({ id: appNotices.id });

    await tx.insert(appNoticeTranslations).values([
      { noticeId: notice.id, locale: "ko", title: titleKo, body: bodyKo },
      { noticeId: notice.id, locale: "en", title: titleEn, body: bodyEn },
    ]);
  });

  try {
    const android = await fetchCurrentAndroidConfig();
    await publishAppNotice(android);
  } catch (err) {
    // DB엔 이미 저장됐으니 어드민이 "저장은 됐는데 게시가 실패했다"는 걸 알아야 재시도(다른 공지를
    // 추가/삭제하면 그 시점에 다시 게시 시도됨)하거나 원인을 볼 수 있다.
    const message = err instanceof Error ? err.message : String(err);
    return redirectToList(origin, { error: "publish_failed", detail: message.slice(0, 200) });
  }

  return redirectToList(origin, { success: "1" });
}
