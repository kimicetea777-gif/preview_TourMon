import Link from "next/link";
import type { CSSProperties } from "react";

const SECTIONS = [
  {
    href: "/admin/monsters",
    title: "몬스터",
    description: "몬스터 도감 목록을 보고 새 몬스터를 추가합니다.",
  },
  {
    href: "/admin/tour-sync",
    title: "TourAPI 배치 동기화",
    description: "TourAPI 관광지 데이터를 다시 받아오고 좌표 중복 그룹을 재계산합니다.",
  },
  {
    href: "/admin/notices",
    title: "공지",
    description: "앱에 노출되는 공지를 추가/삭제합니다 — 저장 즉시 R2에 게시됩니다.",
  },
] as const;

const cardStyle: CSSProperties = {
  display: "block",
  border: "1px solid #ddd",
  borderRadius: 8,
  padding: 20,
  textDecoration: "none",
  color: "inherit",
};

export default function AdminHomePage() {
  return (
    <div>
      <h1>관리자 콘솔</h1>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))",
          gap: 16,
          marginTop: 16,
        }}
      >
        {SECTIONS.map((s) => (
          <Link key={s.href} href={s.href} style={cardStyle}>
            <h2 style={{ margin: "0 0 8px" }}>{s.title}</h2>
            <p style={{ margin: 0, color: "#666", fontSize: 14 }}>{s.description}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
