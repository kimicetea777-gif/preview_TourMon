// 어드민 로그인 시작 — PKCE code_verifier/state를 서버에서 만들어 pending 쿠키에 잠깐 담아두고
// AS 로그인 화면으로 리다이렉트한다. 이 경로 자체는 AS에 등록할 필요 없음(redirect_uri가 아님) —
// 실제 콜백은 /admin/callback(AS에 등록된 값, route.ts).
import { NextResponse } from "next/server";
import { issuer } from "@/lib/auth";
import { randomToken, toCodeChallenge } from "@/lib/admin/pkce";
import { ADMIN_BASE_URL, ADMIN_CLIENT_ID, setPendingLoginCookie } from "@/lib/admin/server-session";

const SCOPE = "openid profile";

export async function GET() {
  const codeVerifier = randomToken();
  const state = randomToken(16);
  const codeChallenge = await toCodeChallenge(codeVerifier);

  const authorizeUrl = new URL("/oauth2/authorize", issuer);
  authorizeUrl.searchParams.set("response_type", "code");
  authorizeUrl.searchParams.set("client_id", ADMIN_CLIENT_ID);
  authorizeUrl.searchParams.set("redirect_uri", new URL("/admin/callback", ADMIN_BASE_URL).toString());
  authorizeUrl.searchParams.set("scope", SCOPE);
  authorizeUrl.searchParams.set("state", state);
  authorizeUrl.searchParams.set("code_challenge", codeChallenge);
  authorizeUrl.searchParams.set("code_challenge_method", "S256");

  const response = NextResponse.redirect(authorizeUrl);
  setPendingLoginCookie(response, { codeVerifier, state });
  return response;
}
