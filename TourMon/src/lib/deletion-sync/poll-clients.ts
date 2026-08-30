// AS의 deleted-users(8-3)/membership-events(8-4) 내부 폴링 API 얇은 래퍼
// (Auth_Server_Folder/Document/connect_manual.md 8-3/8-4, TypeButter 참고 구현과 동일 계약).
import { getDeletionSyncAccessToken } from "./as-token-client";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

const issuer = requireEnv("AS_ISSUER_URL");

export type DeletedUserEvent = {
  type: "ACCOUNT_DELETED";
  id: number;
  userId: string;
  deletedAt: string;
};

export type MembershipEvent = {
  type: "CLIENT_WITHDRAWN" | "CLIENT_BANNED" | "CLIENT_ACTIVATED";
  id: number;
  userId: string;
  clientId: string;
  changedAt: string;
};

// hasMore 필드가 응답에 없음 — items.length < limit이면 끝(AS 쪽 계약).
export const DELETION_SYNC_PAGE_LIMIT = 500;

async function pollInternal<T>(
  path: string,
  since: Date,
  sinceId: number | null,
): Promise<T[]> {
  const token = await getDeletionSyncAccessToken();
  const url = new URL(`${issuer}${path}`);
  url.searchParams.set("since", since.toISOString());
  if (sinceId != null) url.searchParams.set("sinceId", String(sinceId));
  url.searchParams.set("limit", String(DELETION_SYNC_PAGE_LIMIT));

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    throw new Error(`AS 폴링 실패(${path}): HTTP ${response.status} ${await response.text()}`);
  }
  const body = (await response.json()) as { items: T[] };
  return body.items;
}

export function pollDeletedUsers(since: Date, sinceId: number | null): Promise<DeletedUserEvent[]> {
  return pollInternal<DeletedUserEvent>("/api/internal/deleted-users", since, sinceId);
}

export function pollMembershipEvents(since: Date, sinceId: number | null): Promise<MembershipEvent[]> {
  return pollInternal<MembershipEvent>("/api/internal/membership-events", since, sinceId);
}
