// 1단계: Protomaps 공개 벡터 PMTiles 빌드에서 서울+인천 bbox만 Range 요청으로 추출.
// 전체 글로벌 빌드(~130GB)를 다운로드하지 않음 — pmtiles extract가 필요한 타일만 원격 요청.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import {
  BBOX_STRING,
  DATA_DIR,
  EXTRACTED_VECTOR_PMTILES,
  PMTILES_BIN,
  PROTOMAPS_BUILD_BASE_URL,
  PROTOMAPS_BUILDS_METADATA_URL,
} from "./config.ts";

type BuildMeta = { key: string; uploaded: string; version: string };

async function getLatestBuildUrl(): Promise<string> {
  const res = await fetch(PROTOMAPS_BUILDS_METADATA_URL);
  if (!res.ok) {
    throw new Error(`빌드 메타데이터 조회 실패: ${res.status} ${res.statusText}`);
  }
  const builds = (await res.json()) as BuildMeta[];
  if (builds.length === 0) {
    throw new Error("빌드 메타데이터가 비어 있음");
  }
  const latest = builds[builds.length - 1];
  console.log(`최신 Protomaps 빌드: ${latest.key} (버전 ${latest.version}, ${latest.uploaded})`);
  return `${PROTOMAPS_BUILD_BASE_URL}/${latest.key}`;
}

async function main() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(PMTILES_BIN)) {
    throw new Error(
      `pmtiles.exe가 없음: ${PMTILES_BIN} — README의 go-pmtiles 바이너리 다운로드 단계를 먼저 실행할 것`
    );
  }

  const sourceUrl = await getLatestBuildUrl();

  console.log(`추출 범위(bbox): ${BBOX_STRING}`);
  console.log(`출력: ${EXTRACTED_VECTOR_PMTILES}`);

  execFileSync(
    PMTILES_BIN,
    [
      "extract",
      sourceUrl,
      EXTRACTED_VECTOR_PMTILES,
      `--bbox=${BBOX_STRING}`,
      // Protomaps 공개 벡터 빌드는 z0-15까지만 존재 — z16 래스터는 tileserver-gl이
      // z15 벡터 데이터를 오버줌(업스케일)해서 렌더링
      "--minzoom=0",
      "--maxzoom=15",
    ],
    { stdio: "inherit" }
  );

  console.log("추출 완료.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
