// 강제 업데이트 게이트(android.minSupportedBuild/latestBuild/updateUrl)를 R2의
// config/app-notice.json에 반영한다. 소스는 이 저장소의 scripts/app-notice.json(버전관리됨) —
// 편집 후 `npm run notice:publish`로 업로드한다. 실제 공지(notices 배열)는 여기 없음 — DB에서
// 관리되고 /admin/notices(어드민 콘솔)에서 편집·즉시 게시된다(공지를 여기서 같이 바꾸지 않는 이유는
// src/lib/notice-publish.ts 상단 주석 참고). 이 스크립트를 돌려도 DB의 현재 공지는 그대로 같이
// 실려 나간다 — publishAppNotice()가 항상 DB를 다시 읽어서 합치기 때문에 android만 바뀐다.
//
// 워커가 config/*를 max-age=60으로 서빙하므로 CDN purge 없이 최대 1분이면 앱에 전파됨.
// 자세한 사용법: Document/worker_manual.md.
import "dotenv/config";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { type AndroidConfig, publishAppNotice } from "../src/lib/notice-publish";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_FILE = path.join(__dirname, "app-notice.json");

async function main(): Promise<void> {
  const text = await fs.readFile(SOURCE_FILE, "utf8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    throw new Error(`app-notice.json이 유효한 JSON이 아님: ${(err as Error).message}`);
  }

  const android = (parsed as { android?: unknown }).android;
  if (!android || typeof android !== "object") {
    throw new Error("app-notice.json에 android 블록이 없음");
  }

  const result = await publishAppNotice(android as AndroidConfig);
  console.log(`업로드 완료 — 공지 ${result.noticeCount}건 포함, ${result.bytes}B`);
  console.log(`https://assets.kimicetea.app/config/app-notice.json — 최대 60초 뒤 앱에 반영(purge 불필요)`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
