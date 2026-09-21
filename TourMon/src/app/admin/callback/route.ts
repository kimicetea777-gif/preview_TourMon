// AS가 로그인 후 돌아오는 redirect_uri — AS application.yml의 TourMon-admin-web client 등록값과
// 정확히 일치해야 한다(Auth_Server_Folder/Document/connect_manual.md 2-3-1). code exchange를
// 브라우저가 아니라 이 서버 라우트가 대신 한다(BFF) — 응답 토큰은 브라우저 JS에 전혀 노출되지 않고
// httpOnly 쿠키로만 저장되므로, AS의 token endpoint에 CORS를 열 필요도 없다.
import { NextResponse, type NextRequest } from "next/server";
import { issuer } from "@/lib/auth";
import {
  ADMIN_BASE_URL,
  ADMIN_CLIENT_ID,
  ADMIN_PENDING_COOKIE,
  readPendingLogin,
  setAdminSessionCookie,
  type TokenResponseBody,
} from "@/lib/admin/server-session";

function redirectToLogin(error: string): NextResponse {
  const loginUrl = new URL("/admin/login", ADMIN_BASE_URL);
  loginUrl.searchParams.set("error", error);
  const response = NextResponse.redirect(loginUrl);
  response.cookies.delete(ADMIN_PENDING_COOKIE);
  return response;
}

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;

  const oauthError = searchParams.get("error");
  if (oauthError) return redirectToLogin(oauthError);

  const code = searchParams.get("code");
  const state = searchParams.get("state");
  if (!code || !state) return redirectToLogin("missing_code");

  const pending = readPendingLogin(request.cookies.get(ADMIN_PENDING_COOKIE)?.value);
  if (!pending) return redirectToLogin("login_expired");
  if (pending.state !== state) return redirectToLogin("state_mismatch");

  const tokenResponse = await fetch(new URL("/oauth2/token", issuer), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: new URL("/admin/callback", ADMIN_BASE_URL).toString(),
      client_id: ADMIN_CLIENT_ID,
      code_verifier: pending.codeVerifier,
    }),
  });

  if (!tokenResponse.ok) return redirectToLogin("token_exchange_failed");

  const tokens = (await tokenResponse.json()) as TokenResponseBody;

  const response = NextResponse.redirect(new URL("/admin", ADMIN_BASE_URL));
  response.cookies.delete(ADMIN_PENDING_COOKIE);
  setAdminSessionCookie(response, tokens);
  return response;
}
