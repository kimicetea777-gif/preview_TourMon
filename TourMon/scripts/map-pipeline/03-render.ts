// 3단계: 로컬에서 실행 중인 tileserver-gl에 z/x/y 타일을 순회 요청해서 래스터 PNG로 저장.
// 사전 조건: `docker run ... maptiler/tileserver-gl --config /data/tileserver/config.json`
// 로 tileserver-gl이 TILESERVER_PORT에 떠 있어야 함 (README 참고).
import fs from "node:fs";
import path from "node:path";
import {
  BBOX,
  MAX_ZOOM,
  MIN_ZOOM,
  RENDERED_TILES_DIR,
  RENDER_CONCURRENCY,
  TILESERVER_PORT,
  TILESERVER_STYLE_NAME,
} from "./config.ts";

function lon2tile(lon: number, z: number): number {
  return Math.floor(((lon + 180) / 360) * 2 ** z);
}

function lat2tile(lat: number, z: number): number {
  const rad = (lat * Math.PI) / 180;
  return Math.floor(((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * 2 ** z);
}

type Tile = { z: number; x: number; y: number };

function computeTileList(): Tile[] {
  const tiles: Tile[] = [];
  for (let z = MIN_ZOOM; z <= MAX_ZOOM; z++) {
    const x1 = lon2tile(BBOX.minLon, z);
    const x2 = lon2tile(BBOX.maxLon, z);
    const y1 = lat2tile(BBOX.maxLat, z); // 위도가 커질수록 y는 작아짐
    const y2 = lat2tile(BBOX.minLat, z);
    for (let x = x1; x <= x2; x++) {
      for (let y = y1; y <= y2; y++) {
        tiles.push({ z, x, y });
      }
    }
  }
  return tiles;
}

async function fetchTile(base: string, tile: Tile): Promise<void> {
  const { z, x, y } = tile;
  const outDir = path.join(RENDERED_TILES_DIR, String(z), String(x));
  const outFile = path.join(outDir, `${y}.png`);
  if (fs.existsSync(outFile)) return; // 재실행 시 이미 받은 타일은 건너뜀

  const res = await fetch(`${base}/${z}/${x}/${y}.png`);
  if (!res.ok) {
    throw new Error(`타일 요청 실패 z${z}/${x}/${y}: ${res.status} ${res.statusText}`);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(outFile, buf);
}

async function runPool(tiles: Tile[], base: string, concurrency: number) {
  let cursor = 0;
  let done = 0;
  let failed = 0;
  const startedAt = Date.now();

  async function worker() {
    while (cursor < tiles.length) {
      const idx = cursor++;
      const tile = tiles[idx];
      try {
        await fetchTile(base, tile);
      } catch (err) {
        failed++;
        console.error(`실패: z${tile.z}/${tile.x}/${tile.y} —`, (err as Error).message);
      }
      done++;
      if (done % 500 === 0 || done === tiles.length) {
        const elapsedSec = (Date.now() - startedAt) / 1000;
        console.log(
          `${done}/${tiles.length} (실패 ${failed}) — ${elapsedSec.toFixed(0)}s 경과`
        );
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  return { failed };
}

async function main() {
  const base = `http://localhost:${TILESERVER_PORT}/styles/${TILESERVER_STYLE_NAME}`;
  const tiles = computeTileList();
  console.log(`대상 타일 수: ${tiles.length} (z${MIN_ZOOM}-${MAX_ZOOM})`);
  fs.mkdirSync(RENDERED_TILES_DIR, { recursive: true });

  const { failed } = await runPool(tiles, base, RENDER_CONCURRENCY);

  if (failed > 0) {
    console.error(`${failed}개 타일 렌더링 실패 — 스크립트를 재실행하면 성공한 타일은 건너뛰고 이어서 받음`);
    process.exit(1);
  }
  console.log("렌더링 완료.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
