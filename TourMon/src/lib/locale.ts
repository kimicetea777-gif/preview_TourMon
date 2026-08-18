// 7단계 — 서버 라우트 공용 로케일 헬퍼.
// GET/POST 구분 없이 항상 URL 쿼리스트링의 ?locale=만 읽음 — Flutter AuthorizedApiClient가 POST
// 요청에도 쿼리파라미터로 로케일을 실어 보내도록 통일했기 때문(Document/temp.md Phase C 참고),
// body는 안 봐도 돼서 요청 메서드를 신경 쓸 필요가 없음. 지원 로케일 외엔 전부 ko로 폴백.
import type { NextRequest } from "next/server";

export type Locale = "ko" | "en";

export function resolveLocale(request: NextRequest): Locale {
  return request.nextUrl.searchParams.get("locale") === "en" ? "en" : "ko";
}

// 번역 테이블을 조회할 때 IN절에 넣을 로케일 목록 — ko 요청이면 ko 하나만, en이면 en+ko(폴백용)
// 둘 다 가져와서 pickTranslation()이 고르게 함.
export function localesToFetch(locale: Locale): Locale[] {
  return locale === "en" ? ["en", "ko"] : ["ko"];
}

interface Translatable {
  locale: string;
}

// 요청 로케일 row를 우선, 없으면 ko row로 폴백(번역 커버리지가 100%가 아닐 수 있어서).
export function pickTranslation<T extends Translatable>(
  rows: T[],
  locale: Locale,
): T | undefined {
  return rows.find((r) => r.locale === locale) ?? rows.find((r) => r.locale === "ko");
}
