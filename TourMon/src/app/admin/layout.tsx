import type { Metadata } from "next";
import type { ReactNode } from "react";

// robots.ts의 disallow만으로는 크롤링을 막을 뿐, 외부에서 링크가 걸리면 URL 자체는 색인될 수
// 있음 — 어드민 로그인 화면이 검색 결과에 노출되지 않도록 페이지 메타데이터로도 noindex.
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function AdminLayout({ children }: { children: ReactNode }) {
  return children;
}
