// 몬스터 아트(정적 썸네일/움직이는 WebP) 변환 + R2 업로드.
// Resource/Img(정적 PNG, 2048x2048)·Resource/Ani(APNG, 480x480)의 001~019 파일을 WebP로 변환해서
// tourmon-asset-cdn 워커(cloudflare-worker/assets)가 서빙하는 monsters/img/{NNN}.webp,
// monsters/ani/{NNN}.webp 키로 tourmon-assets 버킷(map-pipeline과 동일 버킷)에 올린다.
// scripts/seed.ts의 MONSTER_SPECIES가 만드는 URL(ASSET_CDN_BASE_URL + 이 키 규칙)과 반드시 맞아야 함.
// map-pipeline처럼 여러 단계로 쪼갤 만큼 크지 않은 일회성 작업이라 스크립트 하나로 끝냄
// (Document/temp.md "몬스터 아트 파이프라인" 참고).
import "dotenv/config";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import ffmpegPath from "ffmpeg-static";
import sharp from "sharp";

const execFileAsync = promisify(execFile);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RESOURCE_DIR = path.join(__dirname, "..", "..", "Resource");
const IMG_DIR = path.join(RESOURCE_DIR, "Img");
const ANI_DIR = path.join(RESOURCE_DIR, "Ani");

// 도감 상세(160px)·부화 연출(220px)이 TourMon_App에서 실제 쓰는 최대 크기(코드 확인 완료) —
// 고해상도 화면 여유를 감안해도 소스(2048px)는 훨씬 크므로 이 값으로 축소.
const IMG_MAX_SIZE = 480;
const IMG_QUALITY = 82;
// 움직이는 아트는 소스가 이미 480px라 리사이징 없이 포맷만 WebP로 바꿈(APNG보다 프레임 간
// 압축이 좋아 용량이 줄어듦).
const ANI_QUALITY = 80;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

const s3 = new S3Client({
  region: "auto",
  endpoint: requireEnv("R2_ENDPOINT"),
  credentials: {
    accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
    secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
  },
});
const BUCKET_NAME = requireEnv("R2_BUCKET_NAME");

async function upload(key: string, body: Buffer, contentType: string) {
  await s3.send(
    new PutObjectCommand({ Bucket: BUCKET_NAME, Key: key, Body: body, ContentType: contentType }),
  );
  console.log(`업로드 완료: ${key} (${(body.length / 1024).toFixed(0)}KB)`);
}

// "001_img_common.png" / "006_ani_rare.png" 같은 Resource 파일명에서 앞의 3자리 번호만 추출.
function dexNumberFromFilename(filename: string): string {
  const match = filename.match(/^(\d{3})_/);
  if (!match) {
    throw new Error(`파일명에서 dexNumber를 못 찾음: ${filename}`);
  }
  return match[1];
}

async function processStaticThumbnails() {
  const files = (await fs.readdir(IMG_DIR)).filter((f) => f.endsWith(".png"));
  for (const file of files) {
    const dexNumber = dexNumberFromFilename(file);
    const input = await fs.readFile(path.join(IMG_DIR, file));
    const output = await sharp(input)
      .resize(IMG_MAX_SIZE, IMG_MAX_SIZE, { fit: "inside", withoutEnlargement: true })
      .webp({ quality: IMG_QUALITY })
      .toBuffer();
    await upload(`monsters/img/${dexNumber}.webp`, output, "image/webp");
  }
  console.log(`정적 썸네일 ${files.length}개 처리 완료`);
}

async function processAnimations() {
  // sharp/libvips도 ImageMagick도 이 환경의 libpng엔 APNG 패치가 없어 APNG를 첫 프레임만 읽음
  // → `sharp(input, { animated: true })`가 조용히 정지 WebP를 뱉음(2026-08-28 실측). 그래서
  // APNG demux가 확실한 ffmpeg로 재인코딩함. ffmpeg 바이너리는 ffmpeg-static(devDependency,
  // Docker 미포함 — 이 스크립트는 map-pipeline처럼 개발 PC에서 tsx로 돌리는 일회성 도구).
  if (!ffmpegPath) {
    throw new Error("ffmpeg-static 바이너리를 못 찾음 (플랫폼 미지원?) — `npm install` 재실행 필요");
  }
  const files = (await fs.readdir(ANI_DIR)).filter((f) => f.endsWith(".png"));
  for (const file of files) {
    const dexNumber = dexNumberFromFilename(file);
    const srcPath = path.join(ANI_DIR, file);
    const tmpPath = path.join(os.tmpdir(), `tourmon-ani-${dexNumber}-${process.pid}.webp`);
    try {
      // `-fps_mode passthrough`로 fcTL 프레임 딜레이 유지, `-loop 0`으로 무한 반복. 소스가 이미
      // 480px이라 리사이징 없이 포맷만 바꿈(APNG보다 프레임 간 압축이 좋아 용량이 1/10 수준).
      await execFileAsync(ffmpegPath, [
        "-y", "-hide_banner", "-loglevel", "error",
        "-f", "apng", "-i", srcPath,
        "-c:v", "libwebp", "-loop", "0", "-lossless", "0", "-q:v", String(ANI_QUALITY),
        "-fps_mode", "passthrough",
        "-f", "webp", tmpPath,
      ]);
      const output = await fs.readFile(tmpPath);
      // 결과가 실제로 다중 프레임인지 검증 — ffmpeg가 조용히 단일 프레임을 뱉거나 demux가
      // 실패한 경우를 여기서 잡아 정지 이미지가 배포되는 걸 막음(sharp는 APNG는 못 읽어도
      // 애니메이션 WebP의 pages는 정상적으로 읽음).
      const meta = await sharp(output, { animated: true }).metadata();
      if (!meta.pages || meta.pages < 2) {
        throw new Error(`${file}: 변환 결과가 애니메이션이 아님 (pages=${meta.pages ?? 1})`);
      }
      await upload(`monsters/ani/${dexNumber}.webp`, output, "image/webp");
    } finally {
      await fs.rm(tmpPath, { force: true });
    }
  }
  console.log(`움직이는 아트 ${files.length}개 처리 완료`);
}

async function main() {
  await processStaticThumbnails();
  await processAnimations();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
