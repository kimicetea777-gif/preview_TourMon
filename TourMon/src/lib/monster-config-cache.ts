// /api/monsters/config(4-4 섹션 "Next.js 메모리에 캐싱")의 로케일별 인메모리 캐시. 별도 모듈로
// 뺀 이유는 어드민 몬스터 추가(src/app/api/admin/monsters)가 라우트 파일이 아니라 여기서 직접
// invalidate()를 불러야 해서 — route.ts끼리 서로 import하는 건 피한다.
import type { Locale } from "@/lib/locale";

interface CacheEntry {
  body: unknown;
  expiresAt: number;
}

export const CACHE_TTL_MS = 60_000;

const cache = new Map<Locale, CacheEntry>();

export function readCache(locale: Locale, now: number): unknown | undefined {
  const entry = cache.get(locale);
  return entry && entry.expiresAt >= now ? entry.body : undefined;
}

export function writeCache(locale: Locale, body: unknown, now: number): void {
  cache.set(locale, { body, expiresAt: now + CACHE_TTL_MS });
}

export function invalidateMonsterConfigCache(): void {
  cache.clear();
}
