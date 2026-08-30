// tourmon-asset-cdn — tourmon-pmtiles(../cloudflare) 워커는 PMTiles 전용이라 일반 이미지
// 파일을 못 서빙해서, 몬스터 아트(정적 썸네일/움직이는 WebP)를 위해 별도로 만든 최소 R2 정적
// 파일 서버. 요청 경로를 그대로 R2 객체 키로 써서 조회할 뿐, PMTiles 워커처럼 별도 경로 파싱은
// 필요 없음(Document/temp.md "몬스터 아트 파이프라인" 참고).
//
// config/ 접두사 추가(2026-08-28, Document/worker_manual.md 참고) — 앱 원격 공지 + 최소 지원
// 빌드 게이트용 JSON(config/app-notice.json)을 이 워커로 서빙. 백엔드(Next.js/mini-PC)가 죽어도
// 공지가 떠야 하므로 서버와 완전히 독립된 이 경로에 둔다. config/* 는 즉시성이 중요해서 캐시를
// 짧게(60초) 줘서 purge 없이도 빠르게 전파되게 함(monsters/* 는 그대로 24시간).
interface Env {
  ALLOWED_ORIGINS?: string;
  BUCKET: R2Bucket;
  CACHE_CONTROL?: string;
  CONFIG_CACHE_CONTROL?: string;
}

// 이 워커가 서빙할 수 있는 객체를 이 접두사로만 제한 — 버킷을 tourmon-pmtiles 워커와 공유하다 보니
// (같은 tourmon-assets 버킷) 이 화이트리스트가 없으면 maps/ 등 다른 용도의 객체까지 이 공개
// 엔드포인트로 그대로 노출될 수 있음.
const ALLOWED_PREFIXES = ["monsters/", "config/"];

const CONTENT_TYPES: Record<string, string> = {
  webp: "image/webp",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  json: "application/json; charset=utf-8",
};

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method.toUpperCase() === "POST") {
      return new Response(undefined, { status: 405 });
    }

    const url = new URL(request.url);
    const key = decodeURIComponent(url.pathname.replace(/^\/+/, ""));

    const isConfig = key.startsWith("config/");
    if (!ALLOWED_PREFIXES.some((prefix) => key.startsWith(prefix))) {
      return new Response("Not found", { status: 404 });
    }

    let allowedOrigin = "";
    if (env.ALLOWED_ORIGINS) {
      for (const o of env.ALLOWED_ORIGINS.split(",")) {
        if (o === request.headers.get("Origin") || o === "*") {
          allowedOrigin = o;
        }
      }
    }

    const cache = caches.default;
    const cached = await cache.match(request.url);
    if (cached) {
      const headers = new Headers(cached.headers);
      if (allowedOrigin) headers.set("Access-Control-Allow-Origin", allowedOrigin);
      headers.set("Vary", "Origin");
      return new Response(cached.body, { headers, status: cached.status });
    }

    const object = await env.BUCKET.get(key);
    if (!object) {
      return new Response("Not found", { status: 404 });
    }

    // R2Object.body는 한 번만 읽을 수 있는 스트림이라, 캐시에 저장할 응답과 실제로 반환할 응답
    // 둘 다에 쓰려면 메모리에 한 번 올려서 재사용해야 함 — 몬스터 아트/공지 JSON 모두 파일이 작아
    // (수십~수백KB / 수 KB) 이 방식으로도 부담 없음.
    const data = await object.arrayBuffer();
    const ext = key.split(".").pop()?.toLowerCase() ?? "";

    // config/* 는 공지 즉시성을 위해 짧게, 그 외(monsters/*)는 길게. 워커 자체 캐시(caches.default)와
    // 브라우저/앱 HTTP 캐시 둘 다 이 값을 따르므로, config는 별도 purge 없이 최대 60초면 갱신이 전파됨.
    const cacheControl = isConfig
      ? env.CONFIG_CACHE_CONTROL || "public, max-age=60, must-revalidate"
      : env.CACHE_CONTROL || "public, max-age=86400";

    const headers = new Headers();
    headers.set("Content-Type", CONTENT_TYPES[ext] ?? "application/octet-stream");
    headers.set("Cache-Control", cacheControl);
    headers.set("ETag", object.httpEtag);

    ctx.waitUntil(
      cache.put(request.url, new Response(data, { headers: new Headers(headers), status: 200 }))
    );

    if (allowedOrigin) headers.set("Access-Control-Allow-Origin", allowedOrigin);
    headers.set("Vary", "Origin");
    return new Response(data, { headers, status: 200 });
  },
};
