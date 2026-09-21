import type { ReactNode } from "react";
import { requireAdminSession } from "@/lib/admin/server-session";
import { AdminNav } from "./_components/admin-nav";

// proxy.ts가 이미 유효성(role 포함)을 보장한 뒤에만 이 레이아웃에 도달한다 — 여기서는
// 헤더에 보여줄 role만 다시 읽는다(JWKS는 캐시돼 있어 네트워크 호출 없이 저렴함).
export default async function AdminProtectedLayout({ children }: { children: ReactNode }) {
  const auth = await requireAdminSession();

  return (
    <div>
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "12px 24px",
          borderBottom: "1px solid #ddd",
        }}
      >
        <strong>TourMon 관리자</strong>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span>{auth?.role ?? ""}</span>
          <form action="/api/admin/logout" method="post">
            <button type="submit">로그아웃</button>
          </form>
        </div>
      </header>
      <div style={{ display: "flex", minHeight: "calc(100vh - 49px)" }}>
        <aside
          style={{
            width: 220,
            flexShrink: 0,
            borderRight: "1px solid #ddd",
            padding: "16px 12px",
          }}
        >
          <AdminNav />
        </aside>
        <main style={{ flex: 1, padding: 24, minWidth: 0 }}>{children}</main>
      </div>
    </div>
  );
}
