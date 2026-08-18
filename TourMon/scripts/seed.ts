// 참조 테이블(regions, content_types, egg_types) 시드 데이터. init_plan.md 6번 DB 스키마 섹션 참고.
// 몇 번 다시 실행해도 안전하도록 upsert로 작성 (idempotent).
import "dotenv/config";
import { eq } from "drizzle-orm";
import { db } from "../src/db";
import {
  contentTypes,
  eggTypeTranslations,
  eggTypes,
  monsterAttributeWeights,
  monsterSpecies,
  monsterSpeciesTranslations,
  rarityWeightMultipliers,
  regions,
} from "../src/db/schema";

const REGIONS = [
  { code: "11", name: "서울특별시", isEnabled: true },
  { code: "28", name: "인천광역시", isEnabled: true },
] as const;

// name/id(국문코드)/foreignCode(다국어코드) — init_plan.md 4-1 섹션 표 그대로.
// eggAcquisitionEnabled: 숙박/음식점/쇼핑은 "관광지"로 보기 애매해 지도엔 표시하되 알 획득만 막음
// (2026-08-18 결정, Document/plan/later.md 좌표 중복 실측 — 쇼핑이 145개 매장 단위 row로 쪼개져
// 있는 등 알 획득 스팟으로서 가치가 낮다는 문제 제기가 계기).
const CONTENT_TYPES = [
  { id: 12, name: "관광지", foreignCode: 76, eggAcquisitionEnabled: true },
  { id: 14, name: "문화시설", foreignCode: 78, eggAcquisitionEnabled: true },
  { id: 15, name: "축제/공연/행사", foreignCode: 85, eggAcquisitionEnabled: true },
  { id: 25, name: "여행코스", foreignCode: null, eggAcquisitionEnabled: true },
  { id: 28, name: "레포츠", foreignCode: 75, eggAcquisitionEnabled: true },
  { id: 32, name: "숙박", foreignCode: 80, eggAcquisitionEnabled: false },
  { id: 38, name: "쇼핑", foreignCode: 79, eggAcquisitionEnabled: false },
  { id: 39, name: "음식점", foreignCode: 82, eggAcquisitionEnabled: false },
] as const;

// 3단계 — 알 획득 placeholder 시드. target_steps/weight는 init_plan.md 5번 섹션에 명시된 대로
// 게임 밸런스 수치가 아직 TBD라 임의값 — DB 값이라 나중에 언제든 조정 가능(하드코딩 아님).
// 7단계 — nameEn/descriptionEn은 placeholder 영문 번역(실제 콘텐츠는 TBD, 나중에 교체 가능).
const EGG_TYPES = [
  {
    rarity: "common" as const,
    targetSteps: 1000,
    weight: "70",
    name: "평범한 알",
    description: "흔하게 발견되는 알.",
    nameEn: "Ordinary Egg",
    descriptionEn: "An egg that is commonly found.",
  },
  {
    rarity: "rare" as const,
    targetSteps: 3000,
    weight: "25",
    name: "희귀한 알",
    description: "좀처럼 보기 힘든 알.",
    nameEn: "Rare Egg",
    descriptionEn: "An egg that is rarely seen.",
  },
  {
    rarity: "epic" as const,
    targetSteps: 4500,
    weight: "4",
    name: "서사의 알",
    description: "깊은 이야기를 품은 듯한 알.",
    nameEn: "Epic Egg",
    descriptionEn: "An egg that seems to hold a deep story.",
  },
  {
    rarity: "legendary" as const,
    targetSteps: 6000,
    weight: "1",
    name: "전설의 알",
    description: "극히 드물게 나타나는 알.",
    nameEn: "Legendary Egg",
    descriptionEn: "An egg that appears extremely rarely.",
  },
];

// 4단계 — 부화. 실제 몬스터 아트/이름/속성 밸런스는 게임 디자인 TBD(init_plan.md 5번 섹션) —
// 부화 파이프라인(결정 로직→로컬 저장→연출)을 끝까지 테스트할 수 있게 속성×희귀도 조합마다
// placeholder 종 하나씩만 채워둠. image_url은 R2에 실제 아트가 없어서 placehold.co 임시 이미지 —
// 나중에 실제 아트로 교체 시 이 URL만 갱신하면 됨(그림 파일 자체는 어디에도 저장 안 해둠).
const ATTRIBUTES = ["grass", "water", "fire", "psychic", "ghost"] as const;
const ATTRIBUTE_NAMES_KO: Record<(typeof ATTRIBUTES)[number], string> = {
  grass: "풀",
  water: "물",
  fire: "불",
  psychic: "초능력",
  ghost: "유령",
};
// 7단계 — placeholder 영문 번역(실제 콘텐츠는 TBD, 나중에 교체 가능).
const ATTRIBUTE_NAMES_EN: Record<(typeof ATTRIBUTES)[number], string> = {
  grass: "Grass",
  water: "Water",
  fire: "Fire",
  psychic: "Psychic",
  ghost: "Ghost",
};
const RARITIES = ["common", "rare", "epic", "legendary"] as const;
const RARITY_NAMES_KO: Record<(typeof RARITIES)[number], string> = {
  common: "일반",
  rare: "희귀",
  epic: "서사",
  legendary: "전설",
};
const RARITY_NAMES_EN: Record<(typeof RARITIES)[number], string> = {
  common: "Common",
  rare: "Rare",
  epic: "Epic",
  legendary: "Legendary",
};
const RARITY_PLACEHOLDER_COLOR: Record<(typeof RARITIES)[number], string> = {
  common: "94a3b8/ffffff",
  rare: "8b5cf6/ffffff",
  epic: "f97316/ffffff",
  legendary: "facc15/000000",
};

const MONSTER_SPECIES = ATTRIBUTES.flatMap((attribute, attrIdx) =>
  RARITIES.map((rarity, rarityIdx) => ({
    attribute,
    rarity,
    dexNumber: attrIdx * RARITIES.length + rarityIdx + 1,
    imageUrl: `https://placehold.co/300x300/${RARITY_PLACEHOLDER_COLOR[rarity]}?text=${attribute}-${rarity}`,
    name: `${RARITY_NAMES_KO[rarity]} ${ATTRIBUTE_NAMES_KO[attribute]} 몬스터`,
    description: `${ATTRIBUTE_NAMES_KO[attribute]} 속성의 ${RARITY_NAMES_KO[rarity]} 등급 몬스터.`,
    nameEn: `${RARITY_NAMES_EN[rarity]} ${ATTRIBUTE_NAMES_EN[attribute]} Monster`,
    descriptionEn: `A ${RARITY_NAMES_EN[rarity]}-tier ${ATTRIBUTE_NAMES_EN[attribute]}-type monster.`,
  })),
);

// 알 희귀도 대비 몬스터 희귀도가 높을수록 배율을 낮춰서 "희귀 알일수록 희귀 몬스터 확률↑"를 구현
// (init_plan.md 4-3 섹션 2차 로직). 2026-08-16 결정: 등급 격차 2단계 이상은 아예 0%로 차단하는
// 문턱 방식으로 확정 — 서사 몬스터는 희귀 알 이상에서만, 전설 몬스터는 서사 알 이상에서만 나옴
// (예: 일반 알로는 절대 전설/서사 몬스터가 안 나옴). 격차 1단계(예: 희귀 알→서사 몬스터)는 여전히
// 가능하되 확률은 낮춤. 정확한 수치는 밸런스 TBD — 문턱을 넘긴 범위 안에서의 세부 확률만 placeholder.
const RARITY_GAP_MULTIPLIER = ["1", "0.3", "0", "0"];
function rarityMultiplier(eggRarity: string, monsterRarity: string): string {
  const gap = RARITIES.indexOf(monsterRarity as (typeof RARITIES)[number]) -
    RARITIES.indexOf(eggRarity as (typeof RARITIES)[number]);
  return gap <= 0 ? "1" : RARITY_GAP_MULTIPLIER[Math.min(gap, RARITY_GAP_MULTIPLIER.length - 1)];
}

async function main() {
  for (const region of REGIONS) {
    await db
      .insert(regions)
      .values(region)
      .onConflictDoUpdate({
        target: regions.code,
        set: { name: region.name, isEnabled: region.isEnabled },
      });
  }
  console.log(`regions 시드 완료 (${REGIONS.length}행)`);

  for (const contentType of CONTENT_TYPES) {
    await db
      .insert(contentTypes)
      .values(contentType)
      .onConflictDoUpdate({
        target: contentTypes.id,
        set: {
          name: contentType.name,
          foreignCode: contentType.foreignCode,
          eggAcquisitionEnabled: contentType.eggAcquisitionEnabled,
        },
      });
  }
  console.log(`content_types 시드 완료 (${CONTENT_TYPES.length}행)`);

  // egg_types는 SERIAL PK 외에 자연 키가 없어서 onConflictDoUpdate 패턴을 못 씀 —
  // rarity당 최대 1행이라는 현재 설계 전제로 등급별로 있으면 갱신, 없으면 삽입.
  // 번역(eggTypeTranslations)은 (eggTypeId, locale) 복합 PK라 로케일별로 upsert.
  for (const eggType of EGG_TYPES) {
    const [existing] = await db
      .select({ id: eggTypes.id })
      .from(eggTypes)
      .where(eq(eggTypes.rarity, eggType.rarity))
      .limit(1);

    let eggTypeId: number;
    if (existing) {
      await db
        .update(eggTypes)
        .set({ targetSteps: eggType.targetSteps, weight: eggType.weight })
        .where(eq(eggTypes.id, existing.id));
      eggTypeId = existing.id;
    } else {
      const [inserted] = await db
        .insert(eggTypes)
        .values({
          rarity: eggType.rarity,
          targetSteps: eggType.targetSteps,
          weight: eggType.weight,
        })
        .returning({ id: eggTypes.id });
      eggTypeId = inserted.id;
    }

    for (const t of [
      { locale: "ko" as const, name: eggType.name, description: eggType.description },
      { locale: "en" as const, name: eggType.nameEn, description: eggType.descriptionEn },
    ]) {
      await db
        .insert(eggTypeTranslations)
        .values({ eggTypeId, locale: t.locale, name: t.name, description: t.description })
        .onConflictDoUpdate({
          target: [eggTypeTranslations.eggTypeId, eggTypeTranslations.locale],
          set: { name: t.name, description: t.description },
        });
    }
  }
  console.log(`egg_types(+translations) 시드 완료 (${EGG_TYPES.length}행)`);

  // monster_species는 dex_number가 자연 키(UNIQUE) — 이 값으로 upsert.
  const speciesIds: number[] = [];
  for (const species of MONSTER_SPECIES) {
    const [row] = await db
      .insert(monsterSpecies)
      .values({
        attribute: species.attribute,
        rarity: species.rarity,
        dexNumber: species.dexNumber,
        imageUrl: species.imageUrl,
      })
      .onConflictDoUpdate({
        target: monsterSpecies.dexNumber,
        set: { attribute: species.attribute, rarity: species.rarity, imageUrl: species.imageUrl },
      })
      .returning({ id: monsterSpecies.id });
    speciesIds.push(row.id);

    for (const t of [
      { locale: "ko" as const, name: species.name, description: species.description },
      { locale: "en" as const, name: species.nameEn, description: species.descriptionEn },
    ]) {
      await db
        .insert(monsterSpeciesTranslations)
        .values({ monsterSpeciesId: row.id, locale: t.locale, name: t.name, description: t.description })
        .onConflictDoUpdate({
          target: [monsterSpeciesTranslations.monsterSpeciesId, monsterSpeciesTranslations.locale],
          set: { name: t.name, description: t.description },
        });
    }
  }
  console.log(`monster_species(+translations) 시드 완료 (${MONSTER_SPECIES.length}행)`);

  // 장소(content_type)별 몬스터 속성 가중치는 게임 디자인 TBD — 지금은 모든 종을 동일 가중치(1)로
  // 배정해서 결정 로직 자체를 테스트 가능하게만 해둠(init_plan.md 4-4 섹션). 나중에 장소별로
  // 특정 속성이 더 잘 나오게 하려면 이 값들만 조정하면 됨(코드 변경 불필요).
  let attributeWeightRows = 0;
  for (const contentType of CONTENT_TYPES) {
    for (const speciesId of speciesIds) {
      await db
        .insert(monsterAttributeWeights)
        .values({ contentTypeId: contentType.id, monsterSpeciesId: speciesId, weight: "1" })
        .onConflictDoUpdate({
          target: [monsterAttributeWeights.contentTypeId, monsterAttributeWeights.monsterSpeciesId],
          set: { weight: "1" },
        });
      attributeWeightRows += 1;
    }
  }
  console.log(`monster_attribute_weights 시드 완료 (${attributeWeightRows}행)`);

  let multiplierRows = 0;
  for (const eggRarity of RARITIES) {
    for (const monsterRarity of RARITIES) {
      await db
        .insert(rarityWeightMultipliers)
        .values({
          eggRarity,
          monsterRarity,
          multiplier: rarityMultiplier(eggRarity, monsterRarity),
        })
        .onConflictDoUpdate({
          target: [rarityWeightMultipliers.eggRarity, rarityWeightMultipliers.monsterRarity],
          set: { multiplier: rarityMultiplier(eggRarity, monsterRarity) },
        });
      multiplierRows += 1;
    }
  }
  console.log(`rarity_weight_multipliers 시드 완료 (${multiplierRows}행)`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => process.exit(0));
