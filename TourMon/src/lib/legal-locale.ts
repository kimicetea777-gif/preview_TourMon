import { headers } from "next/headers";
import type { LegalLocale } from "@/content/legal/types";

export type { LegalLocale };

export async function resolveLegalLocale(searchParams: {
  locale?: string | string[];
}): Promise<LegalLocale> {
  const queryLocale = Array.isArray(searchParams.locale)
    ? searchParams.locale[0]
    : searchParams.locale;

  if (queryLocale === "en") return "en";
  if (queryLocale === "ko") return "ko";

  const acceptLanguage = (await headers()).get("accept-language") ?? "";
  return acceptLanguage.toLowerCase().startsWith("en") ? "en" : "ko";
}
