// 어드민 세션(BFF) — access_token/refresh_token은 브라우저 JS에 전혀 노출되지 않고 이 httpOnly
// 쿠키 안에만 존재한다. code exchange/refresh는 전부 서버(admin/login, admin/callback, proxy.ts)가
// AS와 직접(서버-to-서버) 주고받는다 — Auth_Server_Folder/Document/connect_manual.md 2-3-1 참고.
import { cookies } from "next/headers";
import type { NextResponse } from "next/server";
import { isAdminRole, verifyJwtRole, type AuthContext } from "@/lib/auth";

export const ADMIN_SESSION_COOKIE = "tourmon_admin_session";
export const ADMIN_PENDING_COOKIE = "tourmon_admin_pending";
export const ADMIN_CLIENT_ID = "TourMon-admin-web";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

// OAuth redirect_uri는 AS(Auth_Server_Folder/.../application.yml TourMon-admin-web
// redirect-uris)에 등록된 값과 정확히 문자열 일치해야 한다 — request.nextUrl.origin처럼 요청마다
// 달라질 수 있는 값(리버스 프록시/터널이 Host 헤더를 잘못 넘기면 그대로 깨짐, 2026-09-15 실측: Cloudflare
// Tunnel을 거쳤는데도 origin이 "https://0.0.0.0:3000"으로 들어온 사례가 있었음)에서 만들면 안 되고,
// 이렇게 고정된 값으로 둬야 한다. 로컬은 http://localhost:3000, 운영은
// https://tourmon.playlist-games.com — .env(운영은 배포 서버의 .env)에 설정.
export const ADMIN_BASE_URL = requireEnv("ADMIN_BASE_URL");

export interface StoredAdminSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: number; // epoch ms
}

export interface TokenResponseBody {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

export interface PendingLogin {
  codeVerifier: string;
  state: string;
}

function cookieOptions(maxAgeSeconds: number) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
    maxAge: maxAgeSeconds,
  };
}

// refresh_token 수명(AS application.yml: 30d)에 맞춘다 — access_token 자체는 30분이라 middleware가
// 매 요청 만료 임박 여부를 다시 확인해서 갱신한다.
const REFRESH_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30;
const PENDING_TTL_SECONDS = 300; // 로그인 화면에서 AS로 갔다 돌아오는 동안만 유지하면 됨

export function setAdminSessionCookie(response: NextResponse, tokens: TokenResponseBody): void {
  const session: StoredAdminSession = {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token,
    expiresAt: Date.now() + tokens.expires_in * 1000,
  };
  response.cookies.set(
    ADMIN_SESSION_COOKIE,
    JSON.stringify(session),
    cookieOptions(REFRESH_TOKEN_TTL_SECONDS),
  );
}

export function setPendingLoginCookie(response: NextResponse, pending: PendingLogin): void {
  response.cookies.set(ADMIN_PENDING_COOKIE, JSON.stringify(pending), cookieOptions(PENDING_TTL_SECONDS));
}

export function readStoredSession(raw: string | undefined): StoredAdminSession | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as StoredAdminSession;
  } catch {
    return null;
  }
}

export function readPendingLogin(raw: string | undefined): PendingLogin | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as PendingLogin;
  } catch {
    return null;
  }
}

// 어드민 API 라우트(POST /api/admin/monsters 등)에서 쓰는 이중 확인 — proxy.ts가 이미 /admin/*,
// /api/admin/* 요청을 게이트하지만(만료 시 refresh까지 처리), matcher 설정 실수로 게이트가
// 빠지는 경우에 대비해 실제로 DB를 바꾸는 라우트는 여기서 한 번 더 스스로 검증한다. proxy.ts가
// 이미 필요하면 refresh했으므로 여기서는 refresh를 시도하지 않고 읽기만 한다.
export async function requireAdminSession(): Promise<AuthContext | null> {
  const store = await cookies();
  const session = readStoredSession(store.get(ADMIN_SESSION_COOKIE)?.value);
  if (!session) return null;
  const auth = await verifyJwtRole(session.accessToken);
  if (!auth || !isAdminRole(auth.role)) return null;
  return auth;
}
