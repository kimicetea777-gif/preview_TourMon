import type { MetadataRoute } from "next";
import { ADMIN_BASE_URL } from "@/lib/admin/server-session";

// robots.ts는 기본적으로 캐시되는 특수 라우트라 `next build` 시점에 한 번 렌더링돼 정적으로
// 굳어버림 — Dockerfile 빌더 스테이지는 ADMIN_BASE_URL을 fail-fast 체크만 통과시키려고
// "http://build-placeholder.invalid" 더미값으로 채워두므로(실제 값은 컨테이너 기동 시
// docker-compose env_file(.env)로만 주입), force-dynamic 없이는 이 더미 URL이 그대로
// 서빙되어 sitemap 링크가 깨진다(Search Console에서 실제로 이렇게 리젝된 사례, 2026-09-17).
export const dynamic = "force-dynamic";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/help", "/privacy", "/terms", "/credits"],
      // /admin(어드민 콘솔)과 /api(리소스 서버 엔드포인트)는 검색 노출 대상이 아님.
      disallow: ["/admin", "/api"],
    },
    sitemap: `${ADMIN_BASE_URL}/sitemap.xml`,
  };
}
