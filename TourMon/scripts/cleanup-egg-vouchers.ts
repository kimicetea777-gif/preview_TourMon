// 6단계 Phase 4 — 90일 지난 미소진 egg_vouchers 정리 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
// 게스트가 알만 받고 회원가입/부화 없이 이탈하면 voucher row가 영구히 안 지워지는 유령 데이터
// 문제를 막는 배치. 수동 실행: npm run vouchers:cleanup.
//
// §6 파기 파이프라인 도입(instrumentation.ts)으로 실제 스케줄링은 그쪽에 얹었음 — 핵심 로직은
// src/lib/egg-voucher-cleanup.ts로 옮기고, 이 파일은 그걸 부르는 CLI 래퍼로만 남음(수동 실행 경로 유지).
import "dotenv/config";
import { cleanupExpiredEggVouchers } from "../src/lib/egg-voucher-cleanup";

async function main() {
  const count = await cleanupExpiredEggVouchers();
  console.log(`egg_vouchers 정리 완료 — 90일 지난 미소진 row ${count}건 삭제`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
