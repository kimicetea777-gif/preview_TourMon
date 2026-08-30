// §6 회원 탈퇴 데이터 파기 파이프라인 — TourMon이 처음으로 AS에 대해 client_credentials OAuth
// 클라이언트 역할을 하는 코드(지금까지는 리소스 서버로 들어오는 토큰만 검증했음, lib/auth.ts 참고).
// deleted-users/membership-events 폴링 전용 access token 발급+캐시.
function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

const issuer = requireEnv("AS_ISSUER_URL");
const clientId = requireEnv("AS_DELETION_SYNC_CLIENT_ID");
const clientSecret = requireEnv("AS_DELETION_SYNC_CLIENT_SECRET");

let cachedToken: { value: string; expiresAt: number } | null = null;

// 폴링 요청 도중 막 만료되는 경합을 피하기 위한 여유.
const EXPIRY_BUFFER_MS = 30_000;

export async function getDeletionSyncAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now) {
    return cachedToken.value;
  }

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const response = await fetch(`${issuer}/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    // scope를 안 주면 AS가 scope claim이 아예 없는 토큰을 내려서(전체 스코프 자동 부여 안 됨, 실측)
    // /api/internal/deleted-users 등에서 403(SCOPE_deletion:read 없음)이 남 — 반드시 명시해야 함.
    body: "grant_type=client_credentials&scope=deletion%3Aread%20membership-events%3Aread",
  });
  if (!response.ok) {
    throw new Error(`AS token 발급 실패: HTTP ${response.status} ${await response.text()}`);
  }

  const body = (await response.json()) as { access_token: string; expires_in: number };
  cachedToken = {
    value: body.access_token,
    expiresAt: now + body.expires_in * 1000 - EXPIRY_BUFFER_MS,
  };
  return cachedToken.value;
}
