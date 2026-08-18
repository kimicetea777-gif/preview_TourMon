// 5단계: 완성된 래스터 PMTiles를 R2 버킷에 업로드.
// go-pmtiles의 내장 upload 커맨드 사용 — 이 한 번의 데이터 파이프라인 작업만을 위해
// 재사용 가능한 R2 클라이언트(src/lib/r2.ts)를 새로 만들지 않음 (Document/temp_2.md 참고).
// 기존 .env의 R2_* 변수명은 그대로 두고, 이 프로세스 안에서만 AWS SDK 표준 이름으로 매핑해서 사용.
import "dotenv/config";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import { PMTILES_BIN, R2_OBJECT_KEY, RASTER_PMTILES } from "./config.ts";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

async function main() {
  if (!fs.existsSync(RASTER_PMTILES)) {
    throw new Error(`업로드할 파일이 없음: ${RASTER_PMTILES} — 04-package.ts를 먼저 실행할 것`);
  }

  const accessKeyId = requireEnv("R2_ACCESS_KEY_ID");
  const secretAccessKey = requireEnv("R2_SECRET_ACCESS_KEY");
  const bucketName = requireEnv("R2_BUCKET_NAME");
  const endpoint = requireEnv("R2_ENDPOINT");

  console.log(`업로드: ${RASTER_PMTILES} -> s3://${bucketName}/${R2_OBJECT_KEY}`);

  execFileSync(
    PMTILES_BIN,
    [
      "upload",
      RASTER_PMTILES,
      R2_OBJECT_KEY,
      `--bucket=s3://${bucketName}?region=auto&endpoint=${endpoint}`,
    ],
    {
      stdio: "inherit",
      env: {
        ...process.env,
        AWS_ACCESS_KEY_ID: accessKeyId,
        AWS_SECRET_ACCESS_KEY: secretAccessKey,
      },
    }
  );

  console.log("업로드 완료.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
