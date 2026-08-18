// 6단계 Phase 5 — 도감 복구(restore). GET /api/eggs와 같은 이유(새 기기/재설치 시 서버에 남아있는
// 부화 기록을 되찾아옴) — 로컬 UserMonster 모델이 그대로 insert 가능하도록 스냅샷 필드까지
// 조인해서 하이드레이트해서 내려줌(Document/study_folder/6-5_... 참고).
import { eq, inArray } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { monsterSpecies, monsterSpeciesTranslations, tourismSpots, userMonsters } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";
import { localesToFetch, pickTranslation, resolveLocale } from "@/lib/locale";

export async function GET(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }
  const locale = resolveLocale(request);

  const [rows, translationRows] = await Promise.all([
    db
      .select({
        id: userMonsters.id,
        monsterSpeciesId: userMonsters.monsterSpeciesId,
        eggId: userMonsters.eggId,
        tourismSpotId: userMonsters.tourismSpotId,
        tourismSpotTitle: tourismSpots.title,
        attribute: monsterSpecies.attribute,
        rarity: monsterSpecies.rarity,
        dexNumber: monsterSpecies.dexNumber,
        imageUrl: monsterSpecies.imageUrl,
        hatchedAt: userMonsters.hatchedAt,
      })
      .from(userMonsters)
      .innerJoin(monsterSpecies, eq(userMonsters.monsterSpeciesId, monsterSpecies.id))
      .leftJoin(tourismSpots, eq(userMonsters.tourismSpotId, tourismSpots.id))
      .where(eq(userMonsters.userId, auth.sub)),
    db
      .select()
      .from(monsterSpeciesTranslations)
      .where(inArray(monsterSpeciesTranslations.locale, localesToFetch(locale))),
  ]);

  const translationsBySpeciesId = new Map<number, typeof translationRows>();
  for (const t of translationRows) {
    const list = translationsBySpeciesId.get(t.monsterSpeciesId) ?? [];
    list.push(t);
    translationsBySpeciesId.set(t.monsterSpeciesId, list);
  }

  return Response.json({
    monsters: rows.map((r) => {
      const translation = pickTranslation(translationsBySpeciesId.get(r.monsterSpeciesId) ?? [], locale);
      return {
        id: r.id,
        monsterSpeciesId: r.monsterSpeciesId,
        eggId: r.eggId,
        tourismSpotId: r.tourismSpotId,
        tourismSpotTitle: r.tourismSpotTitle,
        attribute: r.attribute,
        rarity: r.rarity,
        dexNumber: r.dexNumber,
        imageUrl: r.imageUrl,
        name: translation?.name ?? r.rarity,
        description: translation?.description ?? null,
        hatchedAt: r.hatchedAt,
      };
    }),
  });
}
