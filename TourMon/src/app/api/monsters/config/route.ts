// 4단계 — 부화 시 몬스터 결정에 필요한 설정성 데이터(4-4 섹션: "Next.js 메모리에 캐싱").
// 게스트 모드는 서버가 아니라 클라이언트(Flutter)가 로컬로 몬스터를 결정하므로(순수 확률 계산이라
// 위치 검증처럼 서버가 반드시 필요한 이유가 없음, 6단계 회원 대비 서버 authoritative 판정은 그때
// 별도 라우트로 추가할 자리 — tourmon_planning_status 메모리의 "회원 알 위조 검증" 논의 참고),
// 이 라우트는 클라이언트가 로컬 결정을 하는 데 필요한 원본 테이블을 그대로 내려주기만 함.
// 관리자 수정 API가 아직 없어서 캐시 무효화 트리거가 없으므로 짧은 TTL로 자체 만료시킴.
// 7단계 — ?locale= 지원(로케일별로 캐시를 따로 둠, Document/temp.md Phase B 참고).
import { inArray } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import {
  monsterAttributeWeights,
  monsterSpecies,
  monsterSpeciesTranslations,
  rarityWeightMultipliers,
} from "@/db/schema";
import { localesToFetch, pickTranslation, resolveLocale, type Locale } from "@/lib/locale";

const CACHE_TTL_MS = 60_000;

const cache = new Map<Locale, { body: unknown; expiresAt: number }>();

async function loadConfig(locale: Locale) {
  const [speciesRows, translationRows, attributeWeightRows, multiplierRows] = await Promise.all([
    db.select().from(monsterSpecies),
    db
      .select()
      .from(monsterSpeciesTranslations)
      .where(inArray(monsterSpeciesTranslations.locale, localesToFetch(locale))),
    db.select().from(monsterAttributeWeights),
    db.select().from(rarityWeightMultipliers),
  ]);

  const translationsBySpeciesId = new Map<number, typeof translationRows>();
  for (const t of translationRows) {
    const list = translationsBySpeciesId.get(t.monsterSpeciesId) ?? [];
    list.push(t);
    translationsBySpeciesId.set(t.monsterSpeciesId, list);
  }

  return {
    species: speciesRows.map((s) => {
      const translation = pickTranslation(translationsBySpeciesId.get(s.id) ?? [], locale);
      return {
        id: s.id,
        attribute: s.attribute,
        rarity: s.rarity,
        dexNumber: s.dexNumber,
        imageUrl: s.imageUrl,
        animationUrl: s.animationUrl,
        name: translation?.name ?? s.rarity,
        description: translation?.description ?? null,
      };
    }),
    attributeWeights: attributeWeightRows.map((w) => ({
      contentTypeId: w.contentTypeId,
      monsterSpeciesId: w.monsterSpeciesId,
      weight: Number(w.weight),
    })),
    rarityMultipliers: multiplierRows.map((m) => ({
      eggRarity: m.eggRarity,
      monsterRarity: m.monsterRarity,
      multiplier: Number(m.multiplier),
    })),
  };
}

export async function GET(request: NextRequest) {
  const locale = resolveLocale(request);
  const now = Date.now();
  const cached = cache.get(locale);
  if (!cached || cached.expiresAt < now) {
    cache.set(locale, { body: await loadConfig(locale), expiresAt: now + CACHE_TTL_MS });
  }
  return Response.json(cache.get(locale)!.body);
}
