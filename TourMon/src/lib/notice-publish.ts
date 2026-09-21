// app-notice.json 게시 — scripts/publish-app-notice.ts(CLI, android 블록만 편집)와 어드민 콘솔
// (/admin/notices, notices 배열만 편집) 둘 다 이 publishAppNotice()를 통해서만 R2에 올린다.
//
// 이 파일이 android 설정을 자기 DB나 로컬 파일에서 읽지 않고 매번 현재 R2에 이미 올라가 있는
// app-notice.json에서 fetchCurrentAndroidConfig()로 가져오는 이유: 어드민 콘솔은 배포된
// Docker 컨테이너(.next/standalone) 안에서 돈다 — 이 이미지엔 scripts/ 폴더가 안 들어있어서
// (Dockerfile 빌드 스테이지 전용) scripts/app-notice.json을 런타임에 읽을 수 없다. R2의 공개
// CDN URL은 컨테이너에서도 항상 접근 가능하므로 이쪽을 "현재 android 설정의 출처"로 삼는다.
// android(강제 업데이트 게이트)는 이 어드민 페이지에서 편집하지 않는다 — 릴리스 주기로만 드물게
// 바뀌고 잘못되면 전체 유저가 앱을 못 쓰는 값이라 git 리뷰+의도적 CLI 실행 문턱을 그대로 둔다
// (scripts/app-notice.json, npm run notice:publish).
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { db } from "@/db";
import { appNoticeTranslations, appNotices } from "@/db/schema";
import { ASSET_CDN_BASE_URL } from "@/lib/monster-art";

const R2_KEY = "config/app-notice.json";
const LEVELS = new Set(["info", "warn", "critical"]);

export interface AndroidConfig {
  minSupportedBuild: number;
  latestBuild: number;
  updateUrl: string;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`.env에 ${name}이 없음`);
  return value;
}

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

// 잘못된 JSON을 올리면 전 사용자의 앱이 그 값을 받으므로(특히 minSupportedBuild) 업로드 전에
// 모양을 직접 검증한다 — zod를 새로 들이는 대신 이 프로젝트의 기존 관례(monster-art-upload.ts 등)처럼 수동 체크.
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`app-notice.json 검증 실패: ${message}`);
}

function validatePayload(raw: unknown): void {
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
    (a.minSupportedBuild as number) <= (a.latestBuild as number) || (a.latestBuild as number) === 0,
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

export async function fetchCurrentAndroidConfig(): Promise<AndroidConfig> {
  const response = await fetch(`${ASSET_CDN_BASE_URL}/${R2_KEY}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`현재 게시된 app-notice.json을 못 읽음 (${response.status})`);
  }
  const parsed = (await response.json()) as { android?: unknown };
  assert(isObject(parsed.android), "현재 게시된 app-notice.json에 android 블록이 없음");
  const a = parsed.android;
  assert(typeof a.minSupportedBuild === "number", "android.minSupportedBuild 형식 오류");
  assert(typeof a.latestBuild === "number", "android.latestBuild 형식 오류");
  assert(typeof a.updateUrl === "string", "android.updateUrl 형식 오류");
  return {
    minSupportedBuild: a.minSupportedBuild,
    latestBuild: a.latestBuild,
    updateUrl: a.updateUrl,
  };
}

export interface PublishResult {
  noticeCount: number;
  bytes: number;
}

export async function publishAppNotice(android: AndroidConfig): Promise<PublishResult> {
  const [notices, translations] = await Promise.all([
    db.select().from(appNotices),
    db.select().from(appNoticeTranslations),
  ]);

  const translationsByNoticeId = new Map<number, typeof translations>();
  for (const t of translations) {
    const list = translationsByNoticeId.get(t.noticeId) ?? [];
    list.push(t);
    translationsByNoticeId.set(t.noticeId, list);
  }

  const payload = {
    schemaVersion: 1,
    android,
    notices: notices.map((n) => {
      const ts = translationsByNoticeId.get(n.id) ?? [];
      const ko = ts.find((t) => t.locale === "ko");
      const en = ts.find((t) => t.locale === "en");
      return {
        id: String(n.id),
        level: n.level,
        startsAt: n.startsAt?.toISOString(),
        endsAt: n.endsAt?.toISOString(),
        url: n.url ?? undefined,
        ko: { title: ko?.title ?? "", body: ko?.body ?? "" },
        en: { title: en?.title ?? "", body: en?.body ?? "" },
      };
    }),
  };

  validatePayload(payload);

  const s3 = new S3Client({
    region: "auto",
    endpoint: requireEnv("R2_ENDPOINT"),
    credentials: {
      accessKeyId: requireEnv("R2_ACCESS_KEY_ID"),
      secretAccessKey: requireEnv("R2_SECRET_ACCESS_KEY"),
    },
  });
  const bucket = requireEnv("R2_BUCKET_NAME");
  const body = Buffer.from(JSON.stringify(payload));
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: R2_KEY,
      Body: body,
      ContentType: "application/json; charset=utf-8",
    }),
  );

  return { noticeCount: notices.length, bytes: body.length };
}
