import type { MetadataRoute } from "next";
import { ADMIN_BASE_URL } from "@/lib/admin/server-session";

// robots.ts와 동일한 이유로 force-dynamic 필요 — 그 파일의 주석 참고.
export const dynamic = "force-dynamic";

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return [
    { url: ADMIN_BASE_URL, lastModified: now, changeFrequency: "monthly", priority: 1 },
    { url: `${ADMIN_BASE_URL}/help`, lastModified: now, changeFrequency: "monthly", priority: 0.6 },
    { url: `${ADMIN_BASE_URL}/privacy`, lastModified: now, changeFrequency: "yearly", priority: 0.5 },
    { url: `${ADMIN_BASE_URL}/terms`, lastModified: now, changeFrequency: "yearly", priority: 0.5 },
    { url: `${ADMIN_BASE_URL}/credits`, lastModified: now, changeFrequency: "yearly", priority: 0.3 },
  ];
}
