// 6단계 Phase 5 — 회원 대상 서버 authoritative 부화. 게스트는 여전히 클라이언트가 로컬로
// determineMonster()를 굴리지만(순수 확률 계산이라 서버가 반드시 필요한 이유가 없음), 회원은
// 걸음수 조작/몬스터 조작을 둘 다 막아야 해서 서버가 목표 달성 판정+몬스터 결정을 직접 함
// (init_plan.md 4-3 "목표 걸음수 달성 판정 및 부화 처리" 🖥️🔐, 3단계 후속 논의에서 이미 정한 원칙).
import { and, eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import {
  eggTypes,
  monsterAttributeWeights,
  monsterSpecies,
  monsterSpeciesTranslations,
  rarityWeightMultipliers,
  tourismSpots,
  userEggs,
  userMonsters,
} from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";
import { localesToFetch, pickTranslation, resolveLocale } from "@/lib/locale";
import { determineMonster } from "@/lib/monster-determination";

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }
  const locale = resolveLocale(request);

  const { id: eggId } = await context.params;

  const result = await db.transaction(async (tx) => {
    const [egg] = await tx
      .select()
      .from(userEggs)
      .where(and(eq(userEggs.id, eggId), eq(userEggs.userId, auth.sub)));
    if (!egg) {
      return { status: 404 as const, error: "해당 알을 찾을 수 없음" };
    }
    if (egg.hatchedAt) {
      return { status: 409 as const, error: "이미 부화한 알" };
    }
    // 클라이언트가 보낸 값이 아니라 서버가 직접 누적해온 값으로 판정 — 이 엔드포인트의 존재 이유.
    if (egg.stepsAccumulated < egg.targetSteps) {
      return { status: 422 as const, error: "목표 걸음수 미달" };
    }

    const [eggType] = await tx
      .select({ rarity: eggTypes.rarity })
      .from(eggTypes)
      .where(eq(eggTypes.id, egg.eggTypeId));
    if (!eggType) {
      return { status: 500 as const, error: "알 종류 정보를 찾을 수 없음" };
    }

    // 1차 가중치의 기준이 되는 장소 content_type_id — 관광지가 나중에 정리됐으면 null(균등 폴백,
    // Flutter determineMonster()와 동일 규칙은 monster-determination.ts에서 처리).
    let contentTypeId: number | null = null;
    if (egg.tourismSpotId != null) {
      const [spot] = await tx
        .select({ contentTypeId: tourismSpots.contentTypeId })
        .from(tourismSpots)
        .where(eq(tourismSpots.id, egg.tourismSpotId));
      contentTypeId = spot?.contentTypeId ?? null;
    }

    const [speciesRows, attributeWeightRows, multiplierRows] = await Promise.all([
      tx.select().from(monsterSpecies),
      tx.select().from(monsterAttributeWeights),
      tx.select().from(rarityWeightMultipliers),
    ]);

    const chosen = determineMonster({
      eggRarity: eggType.rarity,
      contentTypeId,
      species: speciesRows,
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
    });

    // determineMonster()는 판정용 최소 필드(id/attribute/rarity)만 다루므로, 응답에 필요한
    // 나머지 필드(dexNumber/imageUrl/animationUrl)는 이미 조회해둔 speciesRows에서 같은 id로 찾음.
    const chosenSpecies = speciesRows.find((s) => s.id === chosen.id)!;

    const monsterId = uuidv7();
    await tx.insert(userMonsters).values({
      id: monsterId,
      userId: auth.sub,
      monsterSpeciesId: chosenSpecies.id,
      eggId: egg.id,
      tourismSpotId: egg.tourismSpotId,
    });
    await tx.update(userEggs).set({ hatchedAt: new Date() }).where(eq(userEggs.id, egg.id));

    const translationRows = await tx
      .select()
      .from(monsterSpeciesTranslations)
      .where(
        and(
          eq(monsterSpeciesTranslations.monsterSpeciesId, chosenSpecies.id),
          inArray(monsterSpeciesTranslations.locale, localesToFetch(locale)),
        ),
      );
    const translation = pickTranslation(translationRows, locale);

    return {
      status: 200 as const,
      body: {
        id: monsterId,
        monsterSpeciesId: chosenSpecies.id,
        attribute: chosenSpecies.attribute,
        rarity: chosenSpecies.rarity,
        dexNumber: chosenSpecies.dexNumber,
        imageUrl: chosenSpecies.imageUrl,
        animationUrl: chosenSpecies.animationUrl,
        name: translation?.name ?? chosenSpecies.rarity,
        description: translation?.description ?? null,
      },
    };
  });

  if (result.status !== 200) {
    return Response.json({ error: result.error }, { status: result.status });
  }
  return Response.json(result.body);
}
