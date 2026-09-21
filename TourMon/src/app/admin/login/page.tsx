type SearchParams = Promise<{ error?: string }>;

export default async function AdminLoginPage({ searchParams }: { searchParams: SearchParams }) {
  const { error } = await searchParams;

  return (
    <main style={{ maxWidth: 360, margin: "80px auto", textAlign: "center" }}>
      <h1>TourMon 관리자</h1>
      {error && <p style={{ color: "crimson" }}>로그인에 실패했습니다({error}) — 다시 시도해 주세요.</p>}
      <form action="/api/admin/login">
        <button type="submit">관리자 로그인</button>
      </form>
    </main>
  );
}
