// 6단계 Phase 5 — 회원 대상 서버 authoritative 부화 판정. TourMon_App/lib/features/monster/
// monster_determination.dart의 determineMonster()를 TypeScript로 그대로 포팅한 것 — 알고리즘
// 자체는 4단계에서 이미 스펙대로 구현/검증됐으므로 새로 설계하지 않고 동일 로직만 옮김
// (Document/study_folder/6-5_... 참고, 게스트는 여전히 클라이언트 로컬 결정).
import type { rarityTierEnum } from "@/db/schema";

type RarityTier = (typeof rarityTierEnum.enumValues)[number];

export interface MonsterSpeciesRow {
  id: number;
  attribute: string;
  rarity: RarityTier;
}

export interface AttributeWeightRow {
  contentTypeId: number;
  monsterSpeciesId: number;
  weight: number;
}

export interface RarityMultiplierRow {
  eggRarity: RarityTier;
  monsterRarity: RarityTier;
  multiplier: number;
}

interface MonsterPoolParams {
  eggRarity: RarityTier;
  contentTypeId: number | null;
  species: MonsterSpeciesRow[];
  attributeWeights: AttributeWeightRow[];
  rarityMultipliers: RarityMultiplierRow[];
}

// determineMonster()가 최종적으로 굴리는 가중치 풀(종 id → 가중치)을 만든다. 롤 직전까지의
// 결정 로직 전부가 여기 있고, determineMonster()는 이 풀에서 하나를 뽑기만 한다. migrate/route.ts의
// 위조 검사는 "클라가 주장한 종이 이 풀에 있나"로 판정하므로(Document/temp.md 이슈 5), 두 경로가
// 정확히 같은 규칙을 보도록 한 곳에 둔다 — 검사가 풀보다 좁으면 정직한 게스트가 거부당한다.
function monsterPool(params: MonsterPoolParams): Map<number, number> {
  const { eggRarity, contentTypeId, species, attributeWeights, rarityMultipliers } = params;
  const speciesById = new Map(species.map((s) => [s.id, s]));

  // 1차 후보: 해당 content_type의 가중치 테이블. 스팟 정보가 없거나(관광지가 나중에 정리된 경우 등)
  // 매칭되는 행이 없으면 전체 종을 균등 가중치로 폴백 — Flutter determineMonster()와 동일 규칙.
  const candidateWeights = new Map<number, number>();
  if (contentTypeId != null) {
    for (const w of attributeWeights) {
      if (w.contentTypeId === contentTypeId && w.weight > 0) {
        candidateWeights.set(w.monsterSpeciesId, w.weight);
      }
    }
  }
  if (candidateWeights.size === 0) {
    for (const s of species) {
      candidateWeights.set(s.id, 1);
    }
  }

  // 2차: 알 희귀도 × 몬스터 희귀도 배율 적용.
  const multiplierByMonsterRarity = new Map<RarityTier, number>();
  for (const m of rarityMultipliers) {
    if (m.eggRarity === eggRarity) {
      multiplierByMonsterRarity.set(m.monsterRarity, m.multiplier);
    }
  }

  const finalWeights = new Map<number, number>();
  for (const [speciesId, weight] of candidateWeights) {
    const s = speciesById.get(speciesId);
    if (!s) continue;
    const multiplier = multiplierByMonsterRarity.get(s.rarity) ?? 1;
    const finalWeight = weight * multiplier;
    if (finalWeight > 0) finalWeights.set(speciesId, finalWeight);
  }

  // 배율 적용 후 전멸(전부 0)하는 극단적 케이스 대비 — 원래 1차 후보로 균등 폴백.
  return finalWeights.size > 0 ? finalWeights : candidateWeights;
}

// 간단한 선형 합동 생성기 기반이 아니라 Math.random() 그대로 사용 — Dart 쪽도 Random()(암호학적
// 안전성 불필요, 게임 확률 연출용)이라 동일 수준. 테스트에서만 주입 가능하도록 매개변수로 뺌.
export function determineMonster(params: MonsterPoolParams & {
  random?: () => number;
}): MonsterSpeciesRow {
  const { species } = params;
  const random = params.random ?? Math.random;

  if (species.length === 0) {
    throw new Error("몬스터 설정 데이터가 비어 있음");
  }
  const speciesById = new Map(species.map((s) => [s.id, s]));
  const pool = monsterPool(params);

  const totalWeight = [...pool.values()].reduce((sum, w) => sum + w, 0);
  let roll = random() * totalWeight;
  for (const [speciesId, weight] of pool) {
    if (roll < weight) {
      return speciesById.get(speciesId)!;
    }
    roll -= weight;
  }
  const lastId = [...pool.keys()][pool.size - 1];
  return speciesById.get(lastId)!;
}

// migrate/route.ts 위조 검사 전용 — 이 알(등급) × 장소에서 determineMonster()가 실제로 내놓을 수
// 있는 종 id 집합. "accept exactly what determineMonster could have produced"가 불변식이라 풀을
// 그대로 재사용한다(검사만 더 좁히면 정직한 게스트 부화 결과가 거부됨).
export function possibleMonsterSpeciesIds(params: MonsterPoolParams): Set<number> {
  return new Set(monsterPool(params).keys());
}
