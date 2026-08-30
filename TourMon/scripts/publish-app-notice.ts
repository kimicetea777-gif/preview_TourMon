// 앱 원격 공지 + 최소 지원 빌드 게이트 JSON을 R2에 올린다.
// 소스는 이 저장소의 scripts/app-notice.json(버전 관리됨) — 편집 후 `npm run notice:publish`로
// tourmon-asset-cdn 워커가 서빙하는 config/app-notice.json 키(tourmon-assets 버킷)에 업로드한다.
// 워커가 config/* 를 max-age=60으로 서빙하므로 CDN purge 없이 최대 1분이면 앱에 전파됨.
// 자세한 사용법: Document/worker_manual.md.
import "dotenv/config";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SOURCE_FILE = path.join(__dirname, "app-notice.json");
const R2_KEY = "config/app-notice.json";
const LEVELS = new Set(["info", "warn", "critical"]);

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

// 잘못된 JSON을 올리면 전 사용자의 앱이 그 값을 받으므로(특히 minSupportedBuild) 업로드 전에
// 모양을 직접 검증한다 — zod를 새로 들이는 대신 monster-art-upload.ts처럼 수동 체크.
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(`app-notice.json 검증 실패: ${message}`);
  }
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function validate(raw: unknown): void {
  assert(isObject(raw), "최상위가 객체가 아님");
  assert(raw.schemaVersion === 1, "schemaVersion은 1이어야 함");

  assert(isObject(raw.android), "android 블록이 없음");
  const a = raw.android;
  for (const k of ["minSupportedBuild", "latestBuild"]) {
    assert(
      typeof a[k] === "number" && Number.isInteger(a[k]) && (a[k] as number) >= 0,
      `android.${k}는 0 이상 정수여야 함`,
    );
  }
  assert(
    typeof a.updateUrl === "string" && (a.updateUrl as string).startsWith("https://"),
    "android.updateUrl은 https URL이어야 함",
  );
  assert(
    (a.minSupportedBuild as number) <= (a.latestBuild as number) ||
      (a.latestBuild as number) === 0,
    "minSupportedBuild가 latestBuild보다 큼 (latestBuild=0은 '미설정'으로 허용)",
  );

  assert(Array.isArray(raw.notices), "notices는 배열이어야 함");
  const ids = new Set<string>();
  for (const [i, n] of (raw.notices as unknown[]).entries()) {
    const at = `notices[${i}]`;
    assert(isObject(n), `${at}가 객체가 아님`);
    assert(typeof n.id === "string" && n.id.length > 0, `${at}.id 없음`);
    assert(!ids.has(n.id as string), `${at}.id 중복: ${n.id as string}`);
    ids.add(n.id as string);
    assert(LEVELS.has(n.level as string), `${at}.level은 info|warn|critical`);
    for (const k of ["startsAt", "endsAt"] as const) {
      if (n[k] !== undefined && n[k] !== null) {
        assert(
          typeof n[k] === "string" && !Number.isNaN(Date.parse(n[k] as string)),
          `${at}.${k}는 ISO8601 문자열이어야 함`,
        );
      }
    }
    if (n.url !== undefined && n.url !== null) {
      assert(typeof n.url === "string" && (n.url as string).startsWith("https://"), `${at}.url은 https`);
    }
    for (const loc of ["ko", "en"] as const) {
      assert(isObject(n[loc]), `${at}.${loc} 없음 (ko/en 둘 다 필수)`);
      const t = n[loc] as Record<string, unknown>;
      assert(typeof t.title === "string" && t.title.length > 0, `${at}.${loc}.title 없음`);
      assert(typeof t.body === "string" && t.body.length > 0, `${at}.${loc}.body 없음`);
    }
  }
}

async function main(): Promise<void> {
  const text = await fs.readFile(SOURCE_FILE, "utf8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    throw new Error(`app-notice.json이 유효한 JSON이 아님: ${(err as Error).message}`);
  }
  validate(parsed);

  const s3 = new S3Client({
    region: "auto",
    endpoint: requireEnv("R2_ENDPOINT"),
    credentials: {
      accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
      secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
    },
  });
  const bucket = requireEnv("R2_BUCKET_NAME");

  // 저장할 땐 공백을 줄인 형태로(전송량 절감) — 소스 파일은 사람이 읽기 좋게 그대로 둠.
  const body = Buffer.from(JSON.stringify(parsed));
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: R2_KEY,
      Body: body,
      ContentType: "application/json; charset=utf-8",
    }),
  );

  const android = (parsed as { android: { minSupportedBuild: number; latestBuild: number } }).android;
  const notices = (parsed as { notices: { id: string; level: string }[] }).notices;
  console.log(`업로드 완료: ${R2_KEY} (${body.length}B)`);
  console.log(`  minSupportedBuild=${android.minSupportedBuild} latestBuild=${android.latestBuild}`);
  console.log(`  notices: ${notices.length ? notices.map((n) => `${n.id}(${n.level})`).join(", ") : "없음"}`);
  console.log(`  https://assets.kimicetea.app/${R2_KEY} — 최대 60초 뒤 앱에 반영(purge 불필요)`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
