// 6단계 Phase 4 — 게스트 → 회원가입 마이그레이션 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
// 로컬 SQLite user_eggs/user_monsters 전체를 받아서, 각 항목을 개별적으로 판정해 서버로 옮긴다.
// 하나가 위조/불일치로 거부돼도 나머지 정직한 항목은 그대로 반영됨(TTL 설계와 같은 철학).
import { and, eq } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import {
  eggTypes,
  eggVouchers,
  monsterSpecies,
  rarityWeightMultipliers,
  userEggs,
  userMonsters,
  users,
} from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";

type LocalEgg = {
  id: string;
  eggTypeId: number;
  rarity: string;
  targetSteps: number;
  stepsAccumulated: number;
  isPartner: boolean;
  tourismSpotId: number | null;
  acquiredAt: string;
  hatchedAt: string | null;
};

type LocalMonster = {
  id: string;
  monsterSpeciesId: number;
  eggId: string | null;
  tourismSpotId: number | null;
  hatchedAt: string;
};

type ItemStatus = "migrated" | "already_done" | "rejected";

function dedupById<T extends { id: string }>(items: T[]): T[] {
  const seen = new Set<string>();
  const result: T[] = [];
  for (const item of items) {
    if (seen.has(item.id)) continue;
    seen.add(item.id);
    result.push(item);
  }
  return result;
}

export async function POST(request: NextRequest) {
  const auth = await verifyAccessToken(request);
  if (!auth) {
    return Response.json({ error: "인증 필요" }, { status: 401 });
  }

  // FK 제약에 기대면 users row가 없을 때 insert가 500으로 그냥 터짐 — /api/auth/me처럼 명시적으로
  // 확인해서 4xx로 응답.
  const [profile] = await db.select({ id: users.id }).from(users).where(eq(users.id, auth.sub));
  if (!profile) {
    return Response.json({ needsOnboarding: true }, { status: 404 });
  }

  const body = await request.json().catch(() => null);
  const rawEggs = Array.isArray(body?.eggs) ? (body.eggs as LocalEgg[]) : null;
  const rawMonsters = Array.isArray(body?.monsters) ? (body.monsters as LocalMonster[]) : null;
  if (!rawEggs || !rawMonsters) {
    return Response.json({ error: "eggs, monsters 배열이 모두 필요함" }, { status: 400 });
  }

  const eggs = dedupById(rawEggs);
  const monsters = dedupById(rawMonsters);

  // 통과한 voucher의 rarity를 이후 몬스터 검증에 씀 — 클라이언트가 보낸 값이 아니라 서버가
  // voucher/기존 row로 직접 확인한 값이어야 위조 검증이 의미가 있음(섹션 D 결정).
  const verifiedEggRarity = new Map<string, "common" | "rare" | "epic" | "legendary">();

  const eggResults: { id: string; status: ItemStatus }[] = [];
  for (const egg of eggs) {
    if (typeof egg?.id !== "string") continue;

    const [alreadyMigrated] = await db
      .select({ id: userEggs.id, eggTypeId: userEggs.eggTypeId })
      .from(userEggs)
      .where(eq(userEggs.id, egg.id));
    if (alreadyMigrated) {
      const [eggType] = await db
        .select({ rarity: eggTypes.rarity })
        .from(eggTypes)
        .where(eq(eggTypes.id, alreadyMigrated.eggTypeId));
      if (eggType) verifiedEggRarity.set(egg.id, eggType.rarity);
      eggResults.push({ id: egg.id, status: "already_done" });
      continue;
    }

    const [voucher] = await db.select().from(eggVouchers).where(eq(eggVouchers.id, egg.id));
    const matches =
      voucher != null &&
      voucher.rarity === egg.rarity &&
      voucher.targetSteps === Number(egg.targetSteps) &&
      voucher.eggTypeId === Number(egg.eggTypeId);
    if (!voucher || !matches) {
      eggResults.push({ id: egg.id, status: "rejected" });
      continue;
    }

    try {
      await db.insert(userEggs).values({
        id: egg.id,
        userId: auth.sub,
        eggTypeId: voucher.eggTypeId,
        tourismSpotId: egg.tourismSpotId ?? null,
        targetSteps: voucher.targetSteps,
        stepsAccumulated: Number(egg.stepsAccumulated) || 0,
        isPartner: Boolean(egg.isPartner),
        acquiredAt: new Date(egg.acquiredAt),
        hatchedAt: egg.hatchedAt ? new Date(egg.hatchedAt) : null,
      });
    } catch {
      eggResults.push({ id: egg.id, status: "rejected" });
      continue;
    }
    // insert가 실제로 성공한 뒤에만 voucher 삭제 — 반대 순서면 insert 실패 시 voucher만 날아가고
    // 그 알은 영구 복구 불가능해짐.
    await db.delete(eggVouchers).where(eq(eggVouchers.id, egg.id));
    verifiedEggRarity.set(egg.id, voucher.rarity);
    eggResults.push({ id: egg.id, status: "migrated" });
  }

  const monsterResults: { id: string; status: ItemStatus }[] = [];
  for (const monster of monsters) {
    if (typeof monster?.id !== "string") continue;

    const [alreadyMigrated] = await db
      .select({ id: userMonsters.id })
      .from(userMonsters)
      .where(eq(userMonsters.id, monster.id));
    if (alreadyMigrated) {
      monsterResults.push({ id: monster.id, status: "already_done" });
      continue;
    }

    const eggRarity = monster.eggId ? verifiedEggRarity.get(monster.eggId) : undefined;
    if (!eggRarity) {
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }

    const [species] = await db
      .select({ id: monsterSpecies.id, rarity: monsterSpecies.rarity })
      .from(monsterSpecies)
      .where(eq(monsterSpecies.id, Number(monster.monsterSpeciesId)));
    if (!species) {
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }

    const [multiplierRow] = await db
      .select({ multiplier: rarityWeightMultipliers.multiplier })
      .from(rarityWeightMultipliers)
      .where(
        and(
          eq(rarityWeightMultipliers.eggRarity, eggRarity),
          eq(rarityWeightMultipliers.monsterRarity, species.rarity),
        ),
      );
    // 이 표는 rarity_tier(4종) × rarity_tier(4종) 조합을 seed.ts가 항상 전부 채워두므로 정상적으론
    // 항상 존재함 — 그럼에도 위조 검증 로직이라 데이터 누락 시엔 허용(1)이 아니라 차단(0)을 기본값으로.
    const multiplier = multiplierRow ? Number(multiplierRow.multiplier) : 0;
    if (multiplier <= 0) {
      // 전역 확률상 절대 안 나오는 격차(예: common 알 → legendary 몬스터) — 위조로 간주하고 거부.
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }

    try {
      await db.insert(userMonsters).values({
        id: monster.id,
        userId: auth.sub,
        monsterSpeciesId: species.id,
        eggId: monster.eggId,
        tourismSpotId: monster.tourismSpotId ?? null,
        hatchedAt: new Date(monster.hatchedAt),
      });
    } catch {
      // eggId unique 제약 위반 포함 — 이미 다른 몬스터 row가 이 알을 소진했으면 거부.
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }
    monsterResults.push({ id: monster.id, status: "migrated" });
  }

  return Response.json({ eggs: eggResults, monsters: monsterResults });
}
