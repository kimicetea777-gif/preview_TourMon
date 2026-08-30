// TourMon 인프라가 "개인 mini-PC 단일 인스턴스"라는 전제(init_plan.md "인프라" 절, schema.ts 캐싱
// 주석 참고)로, 별도 Cloudflare Worker Cron/OS cron 없이 이 인프로세스 스케줄러로 충분하다고 결정
// (Document/temp.md §6-4). 여러 인스턴스로 늘어나면 잡이 중복 실행되므로 그때 재검토할 것.
export async function register() {
  // instrumentation.ts는 Node.js/Edge 런타임 양쪽에서 실행됨 — node-cron/DB 접근은 Edge에서 못 쓰므로
  // Next.js 공식 가이드대로 NEXT_RUNTIME으로 분기.
  if (process.env.NEXT_RUNTIME !== "nodejs") return;

  const cron = await import("node-cron");
  const { syncDeletedUsers } = await import("./lib/deletion-sync/deleted-user-sync");
  const { syncMembershipEvents } = await import("./lib/deletion-sync/membership-event-sync");
  const { finalizeExpiredWithdrawals } = await import("./lib/deletion-sync/finalize-withdrawals");
  const { cleanupExpiredEggVouchers } = await import("./lib/egg-voucher-cleanup");

  // §6 회원 탈퇴 데이터 파기 파이프라인.
  cron.schedule("0 10 4 * * *", () => {
    syncDeletedUsers().catch((e) => console.error("[deletion-sync] deleted-users 스케줄 실패:", e));
  });
  // membership-events 동기화 → finalize를 같은 트리거 안에서 순서 고정(TypeButter 참고 구현과 동일
  // 원칙) — 두 크론을 몇 분 띄워서 따로 돌리면, 방금 재연결한 유저의 CLIENT_ACTIVATED 이벤트를 아직
  // 못 폴링한 상태에서 finalize가 먼저 돌아 잘못 파기하는 경합이 생길 수 있음.
  cron.schedule("0 15 4 * * *", () => {
    syncMembershipEvents()
      .then(() => finalizeExpiredWithdrawals())
      .catch((e) => console.error("[deletion-sync] membership-events 스케줄 실패:", e));
  });
  // egg_vouchers 90일 TTL 정리 — 원래 독립 스크립트(scripts/cleanup-egg-vouchers.ts)였던 걸 흡수.
  cron.schedule("0 20 4 * * *", () => {
    cleanupExpiredEggVouchers().catch((e) => console.error("[egg-voucher-cleanup] 스케줄 실패:", e));
  });
}
