// 참조 테이블(regions, content_types, egg_types) 시드 데이터. init_plan.md 6번 DB 스키마 섹션 참고.
// 몇 번 다시 실행해도 안전하도록 upsert로 작성 (idempotent).
import "dotenv/config";
import { eq } from "drizzle-orm";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
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

// 3단계 — 알 획득 placeholder 시드. target_distance_meters/weight는 init_plan.md 5번 섹션에 명시된
// 대로 게임 밸런스 수치가 아직 TBD라 임의값 — DB 값이라 나중에 언제든 조정 가능(하드코딩 아님).
// Health Connect 전환(Document/temp.md "통합 결정", 2026-08-19)으로 걸음수 단위였던 값을 그대로
// meters로 재해석 — 등급 간 비율(1:3:4.5:6)만 유지, 새 밸런스 수치를 발명하지 않음.
// 7단계 — nameEn/descriptionEn은 placeholder 영문 번역(실제 콘텐츠는 TBD, 나중에 교체 가능).
const EGG_TYPES = [
  {
    rarity: "common" as const,
    targetDistanceMeters: 1000,
    weight: "70",
    name: "평범한 알",
    description: "흔하게 발견되는 알.",
    nameEn: "Ordinary Egg",
    descriptionEn: "An egg that is commonly found.",
  },
  {
    rarity: "rare" as const,
    targetDistanceMeters: 3000,
    weight: "25",
    name: "희귀한 알",
    description: "좀처럼 보기 힘든 알.",
    nameEn: "Rare Egg",
    descriptionEn: "An egg that is rarely seen.",
  },
  {
    rarity: "epic" as const,
    targetDistanceMeters: 4500,
    weight: "4",
    name: "서사의 알",
    description: "깊은 이야기를 품은 듯한 알.",
    nameEn: "Epic Egg",
    descriptionEn: "An egg that seems to hold a deep story.",
  },
  {
    rarity: "legendary" as const,
    targetDistanceMeters: 6000,
    weight: "1",
    name: "전설의 알",
    description: "극히 드물게 나타나는 알.",
    nameEn: "Legendary Egg",
    descriptionEn: "An egg that appears extremely rarely.",
  },
];

// 4단계 — 부화. 실제 아트/이름/설명 19종(Document/monster_enc_kor.md·monster_enc_eng.md,
// Resource/Ani·Resource/Img 001~019)이 갖춰지면서 이전의 "속성×희귀도 placeholder 20종" 그리드를
// 대체함(2026-08-26). 이름/설명은 두 md 파일에서 직접 파싱해서 가져옴 — 문서를 고치고 다시
// db:seed를 돌리면 그대로 반영되므로 시드 파일에 텍스트를 중복 보관하지 않음.
//
// 속성은 지금 당장 안 씀(2026-08-26 결정, Document/temp.md 참고) — 몬스터가 본격적으로 늘어날 때
// 다시 도입 예정. monster_attribute_weights의 실제 가중치가 이미 종 단위로 직접 매핑돼 있어서
// (attribute 컬럼을 안 거침, 아래 시드 로직 참고) 값 하나로 통일해도 부화 확률엔 영향 없음.
const RARITIES = ["common", "rare", "epic", "legendary"] as const;
const ATTRIBUTE_PLACEHOLDER = "grass" as const;

// Resource/Ani·Resource/Img의 001~019 파일명 규칙과 동일 — scripts/monster-art/upload.ts가 R2에
// 올리는 객체 키(monsters/img/{NNN}.webp, monsters/ani/{NNN}.webp)와 반드시 같은 규칙을 유지할 것.
const ASSET_CDN_BASE_URL = "https://assets.kimicetea.app";
const DEX_NUMBERS = Array.from({ length: 19 }, (_, i) => i + 1);

function rarityForDexNumber(dexNumber: number): (typeof RARITIES)[number] {
  if (dexNumber <= 5) return "common";
  if (dexNumber <= 14) return "rare";
  if (dexNumber <= 17) return "epic";
  return "legendary";
}

type MonsterEncEntry = { name: string; description: string };

// TourMon/Document/monster_enc_kor.md·monster_enc_eng.md의 "#001" ~ "#019" 블록을 파싱 —
// 두 파일 포맷이 동일(#NNN → "1. 이름/Name" → 이름 한 줄 → "2. ..." → 배경 이야기)해서
// 하나의 파서로 같이 처리함. "1." 아래 이유/유래 설명은 게임 화면에 노출 안 함
// (2026-08-26 결정) — "2." 헤딩 이후 내용만 description으로 씀.
function parseMonsterEnc(filePath: string): Map<number, MonsterEncEntry> {
  const raw = fs.readFileSync(filePath, "utf-8");
  const blocks = raw.split(/\n(?=#\d{3}\b)/).filter((b) => /^#\d{3}\b/.test(b.trim()));

  const result = new Map<number, MonsterEncEntry>();
  for (const block of blocks) {
    const numMatch = block.match(/^#(\d{3})/);
    if (!numMatch) continue;
    const dexNumber = Number(numMatch[1]);

    const nameMatch = block.match(/1\.\s*(?:이름|Name)\s*\n+\s*([^\n]+)/);
    if (!nameMatch) throw new Error(`${filePath} #${numMatch[1]}: 이름을 못 찾음`);
    // ko 파일엔 "포슬 (Poseul)"처럼 로마자 표기가 괄호로 붙어있음 — 괄호 앞부분만 이름으로 사용
    // (로마자 이름은 monster_enc_eng.md 쪽에서 그대로 nameEn으로 씀).
    const name = nameMatch[1].replace(/\s*\(.*\)\s*$/, "").trim();

    const descMatch = block.match(/2\.[^\n]*\n([\s\S]*)/);
    if (!descMatch) throw new Error(`${filePath} #${numMatch[1]}: 배경 이야기를 못 찾음`);
    // #005/#006 사이처럼 항목 구분용 "---"가 블록 끝에 딸려올 수 있어 제거.
    const description = descMatch[1].replace(/\n+-{3,}\s*$/, "").trim();

    result.set(dexNumber, { name, description });
  }
  return result;
}

// ESM엔 __dirname이 없어서 map-pipeline/config.ts와 동일한 방식으로 직접 구함.
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOC_DIR = path.join(__dirname, "..", "Document");
const monsterEncKo = parseMonsterEnc(path.join(DOC_DIR, "monster_enc_kor.md"));
const monsterEncEn = parseMonsterEnc(path.join(DOC_DIR, "monster_enc_eng.md"));

const MONSTER_SPECIES = DEX_NUMBERS.map((dexNumber) => {
  const ko = monsterEncKo.get(dexNumber);
  const en = monsterEncEn.get(dexNumber);
  if (!ko) throw new Error(`monster_enc_kor.md에 #${String(dexNumber).padStart(3, "0")}이 없음`);
  if (!en) throw new Error(`monster_enc_eng.md에 #${String(dexNumber).padStart(3, "0")}이 없음`);

  const paddedNumber = String(dexNumber).padStart(3, "0");
  return {
    attribute: ATTRIBUTE_PLACEHOLDER,
    rarity: rarityForDexNumber(dexNumber),
    dexNumber,
    imageUrl: `${ASSET_CDN_BASE_URL}/monsters/img/${paddedNumber}.webp`,
    animationUrl: `${ASSET_CDN_BASE_URL}/monsters/ani/${paddedNumber}.webp`,
    name: ko.name,
    description: ko.description,
    nameEn: en.name,
    descriptionEn: en.description,
  };
});

// 알 희귀도 대비 몬스터 희귀도가 높을수록 배율을 낮춰서 "희귀 알일수록 희귀 몬스터 확률↑"를 구현
// (init_plan.md 4-3 섹션 2차 로직). 2026-08-16 결정: 등급 격차 2단계 이상은 아예 0%로 차단하는
// 문턱 방식으로 확정 — 서사 몬스터는 희귀 알 이상에서만, 전설 몬스터는 서사 알 이상에서만 나옴
// (예: 일반 알로는 절대 전설/서사 몬스터가 안 나옴). 격차 1단계(예: 희귀 알→서사 몬스터)는 여전히
// 가능하되 확률은 낮춤. 정확한 수치는 밸런스 TBD — 문턱을 넘긴 범위 안에서의 세부 확률만 placeholder.
// 2026-08-27 결정: 알 등급보다 "낮은" 등급 몬스터는 아예 안 나오게 함(gap < 0 → 0). 이전엔
// 배율 1이라 희귀 알에서도 일반 몬스터가 흔하게 부화됐음 — 알 등급 이상만 부화되도록 변경.
const RARITY_GAP_MULTIPLIER = ["1", "0.3", "0", "0"];
function rarityMultiplier(eggRarity: string, monsterRarity: string): string {
  const gap = RARITIES.indexOf(monsterRarity as (typeof RARITIES)[number]) -
    RARITIES.indexOf(eggRarity as (typeof RARITIES)[number]);
  if (gap < 0) return "0";
  return gap === 0 ? "1" : RARITY_GAP_MULTIPLIER[Math.min(gap, RARITY_GAP_MULTIPLIER.length - 1)];
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
        .set({ targetDistanceMeters: eggType.targetDistanceMeters, weight: eggType.weight })
        .where(eq(eggTypes.id, existing.id));
      eggTypeId = existing.id;
    } else {
      const [inserted] = await db
        .insert(eggTypes)
        .values({
          rarity: eggType.rarity,
          targetDistanceMeters: eggType.targetDistanceMeters,
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
        animationUrl: species.animationUrl,
      })
      .onConflictDoUpdate({
        target: monsterSpecies.dexNumber,
        set: {
          attribute: species.attribute,
          rarity: species.rarity,
          imageUrl: species.imageUrl,
          animationUrl: species.animationUrl,
        },
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
