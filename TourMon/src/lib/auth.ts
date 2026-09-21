// 6단계 — Next.js 리소스 서버화. AS(Auth_Server)가 발급한 access_token(JWT)을 AS의 JWKS로
// 로컬 검증한다 — Next.js는 OAuth 클라이언트가 아니라서 code 교환/토큰 발급엔 관여하지 않음
// (init_plan.md 4-1, CLAUDE.md "인증은 Direct-to-AS 패턴" 참고).
import { createRemoteJWKSet, jwtVerify } from "jose";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

export const issuer = requireEnv("AS_ISSUER_URL");
const jwks = createRemoteJWKSet(new URL(`${issuer}/oauth2/jwks`));

export interface AuthContext {
  sub: string; // AS users.id(UUID) — TourMon users.id와 동일 값(FK 아님, AS는 외부 시스템)
  role?: string;
}

// aud 클레임은 검증하지 않는다 — AS의 TokenGeneratorConfig가 sub/role/app_role/email만 커스터마이즈하고
// aud는 프레임워크 기본 동작에 맡겨져 있어 항상 실리는지 보장되지 않음. 서명+iss+exp 검증만으로도 이
// 리소스 서버 하나만 신뢰하면 되는 지금 수준에선 충분함.
export async function verifyJwtRole(accessToken: string): Promise<AuthContext | null> {
  try {
    const { payload } = await jwtVerify(accessToken, jwks, { issuer });
    if (typeof payload.sub !== "string") return null;
    return {
      sub: payload.sub,
      role: typeof payload.role === "string" ? payload.role : undefined,
    };
  } catch (err) {
    // 디버깅용 — jwtVerify가 던지는 실패 사유(exp/iss mismatch, 서명 불일치, JWKS fetch 실패 등)가
    // 여기서 삼켜지면 호출부(proxy.ts 등)는 그냥 "무효"로만 보여서 원인을 못 좁힌다.
    console.error("[auth] verifyJwtRole 실패:", err instanceof Error ? err.message : err);
    return null;
  }
}

export async function verifyAccessToken(request: Request): Promise<AuthContext | null> {
  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  return verifyJwtRole(authHeader.slice(7));
}

// 어드민 페이지(/admin, TourMon-admin-web) 게이트 — AS 전역 role(users.role, AS 자체 /admin/**도
// 이 값으로 판정)을 그대로 쓴다. 서비스 로컬 role 컬럼을 따로 두지 않음
// (Auth_Server_Folder/Document/connect_manual.md 2-3-1 참고).
const ADMIN_ROLES = new Set(["ROLE_ADMIN", "ROLE_SUPER_ADMIN"]);

export function isAdminRole(role: string | undefined): boolean {
  return role !== undefined && ADMIN_ROLES.has(role);
}
