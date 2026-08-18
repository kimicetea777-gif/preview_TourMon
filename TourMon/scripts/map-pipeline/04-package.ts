// 4단계: 렌더링된 z/x/y PNG 디렉터리를 MBTiles로 패키징(mb-util) → 최종 래스터 PMTiles로 변환(pmtiles convert).
// 사전 조건: `pip install mbutil`, 03-render.ts 완료.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import {
  PMTILES_BIN,
  RASTER_MBTILES,
  RASTER_PMTILES,
  RENDERED_TILES_DIR,
} from "./config.ts";

function findMbUtilScript(): string {
  const scriptsDir = execFileSync("python", [
    "-c",
    "import sysconfig; print(sysconfig.get_path('scripts'))",
  ])
    .toString()
    .trim();
  const candidate = `${scriptsDir}\\mb-util`;
  if (!fs.existsSync(candidate)) {
    throw new Error(
      `mb-util 스크립트를 찾을 수 없음: ${candidate} — README의 'pip install mbutil' 단계를 먼저 실행할 것`
    );
  }
  return candidate;
}

async function main() {
  if (!fs.existsSync(RENDERED_TILES_DIR)) {
    throw new Error(`렌더링된 타일 디렉터리가 없음: ${RENDERED_TILES_DIR} — 03-render.ts를 먼저 실행할 것`);
  }
  if (fs.existsSync(RASTER_MBTILES)) {
    console.log(`기존 MBTiles 삭제: ${RASTER_MBTILES}`);
    fs.rmSync(RASTER_MBTILES);
  }

  const mbUtilScript = findMbUtilScript();
  console.log(`MBTiles 패키징: ${RENDERED_TILES_DIR} -> ${RASTER_MBTILES}`);
  execFileSync(
    "python",
    [mbUtilScript, "--image_format=png", RENDERED_TILES_DIR, RASTER_MBTILES],
    { stdio: "inherit" }
  );

  console.log(`raster PMTiles 변환: ${RASTER_MBTILES} -> ${RASTER_PMTILES}`);
  execFileSync(PMTILES_BIN, ["convert", RASTER_MBTILES, RASTER_PMTILES, "--force"], {
    stdio: "inherit",
  });

  console.log("패키징 완료.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
