// /admin/*, /api/admin/* 게이트 — httpOnly 쿠키에 담긴 access_token을 JWKS로 검증하고 role을
// 확인한다. 만료 임박 시 여기서 refresh_token으로 조용히 갱신한다(BFF라 refresh_token도 브라우저에
// 노출 안 됨). /admin/login, /admin/callback, /api/admin/login은 로그인 흐름 자체라 제외 —
// 이 셋 말고는 몬스터 추가처럼 실제로 DB를 바꾸는 라우트라 여기서 막는 게 1차 방어선이고,
// 각 라우트도 requireAdminSession()으로 한 번 더 스스로 확인한다(server-session.ts 주석 참고).
import { NextResponse, type NextRequest } from "next/server";
import { isAdminRole, issuer, verifyJwtRole } from "@/lib/auth";
import {
  ADMIN_BASE_URL,
  ADMIN_CLIENT_ID,
  ADMIN_SESSION_COOKIE,
  readStoredSession,
  setAdminSessionCookie,
  type StoredAdminSession,
  type TokenResponseBody,
} from "@/lib/admin/server-session";

const REFRESH_MARGIN_MS = 60_000;

async function refreshSession(session: StoredAdminSession): Promise<TokenResponseBody | null> {
  const response = await fetch(new URL("/oauth2/token", issuer), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: session.refreshToken,
      client_id: ADMIN_CLIENT_ID,
    }),
  });
  if (!response.ok) return null;
  return (await response.json()) as TokenResponseBody;
}

function redirectToLogin(request: NextRequest, reason: string): NextResponse {
  console.error(`[proxy] ${request.nextUrl.pathname} 게이트 실패(${reason}) → /admin/login`);
  // 303 고정 — 이 게이트는 페이지 이동(GET)뿐 아니라 폼 POST(/api/admin/monsters 등)도 통과하는데,
  // 기본 307은 메서드를 보존해서 로그인 "페이지"에 POST가 그대로 가버리면 405가 난다. 303은
  // 항상 GET으로 바꿔 보내므로 두 경우 다 로그인 화면이 뜬다.
  const response = NextResponse.redirect(new URL("/admin/login", ADMIN_BASE_URL), 303);
  response.cookies.delete(ADMIN_SESSION_COOKIE);
  return response;
}

export async function proxy(request: NextRequest): Promise<NextResponse> {
  const { pathname } = request.nextUrl;
  if (pathname === "/admin/login" || pathname === "/admin/callback" || pathname === "/api/admin/login") {
    return NextResponse.next();
  }

  let session = readStoredSession(request.cookies.get(ADMIN_SESSION_COOKIE)?.value);
  let refreshedTokens: TokenResponseBody | null = null;

  if (session && session.expiresAt <= Date.now() + REFRESH_MARGIN_MS) {
    refreshedTokens = await refreshSession(session);
    if (!refreshedTokens) return redirectToLogin(request, "refresh_failed");
    session = {
      accessToken: refreshedTokens.access_token,
      refreshToken: refreshedTokens.refresh_token,
      expiresAt: Date.now() + refreshedTokens.expires_in * 1000,
    };
  }

  if (!session) return redirectToLogin(request, "no_session_cookie");

  const auth = await verifyJwtRole(session.accessToken);
  if (!auth) return redirectToLogin(request, "jwt_verify_failed");
  if (!isAdminRole(auth.role)) return redirectToLogin(request, `not_admin_role(${auth.role ?? "none"})`);

  const response = NextResponse.next();
  if (refreshedTokens) setAdminSessionCookie(response, refreshedTokens);
  return response;
}

export const config = {
  matcher: ["/admin/:path*", "/api/admin/:path*"],
};
