// 6단계 Phase 4 — 게스트 → 회원가입 마이그레이션 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
// 로컬 SQLite user_eggs/user_monsters 전체를 받아서, 각 항목을 개별적으로 판정해 서버로 옮긴다.
// 하나가 위조/불일치로 거부돼도 나머지 정직한 항목은 그대로 반영됨(TTL 설계와 같은 철학).
import { and, eq, isNull } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import {
  eggTypes,
  eggVouchers,
  monsterAttributeWeights,
  monsterSpecies,
  rarityWeightMultipliers,
  tourismSpots,
  userEggs,
  userMonsters,
  users,
} from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";
import { MAX_PLAUSIBLE_SPEED_KMH } from "@/lib/game-config";
import { possibleMonsterSpeciesIds } from "@/lib/monster-determination";

type LocalEgg = {
  id: string;
  eggTypeId: number;
  rarity: string;
  targetDistanceMeters: number;
  distanceAccumulatedMeters: number;
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
      voucher.targetDistanceMeters === Number(egg.targetDistanceMeters) &&
      voucher.eggTypeId === Number(egg.eggTypeId);
    if (!voucher || !matches) {
      eggResults.push({ id: egg.id, status: "rejected" });
      continue;
    }

    // 게스트 부화는 클라이언트가 로컬로 판정하고 서버 확인이 없음(hatch/route.ts 주석 참고).
    // 클라가 보낸 누적 거리를 "voucher 발급(=획득) 시각 ~ 지금" 경과 시간 × 최대 속도로 상한
    // 클램프한다 — /api/distance/sync와 같은 철학(거부가 아니라 초과분을 조용히 버림). 방금 획득한
    // 알에 목표치를 통째로 실어보내 걷기를 건너뛰는 걸 막음. 앵커는 클라 acquiredAt이 아니라
    // 서버가 찍은 voucher.issuedAt — 앵커 자체를 과거로 위조하지 못하게(Document/temp.md 이슈 4).
    // GPS/헬스데이터 자체의 진위까지 보장하진 못함.
    const claimedMeters = Number(egg.distanceAccumulatedMeters) || 0;
    const elapsedMs = Math.max(0, Date.now() - voucher.issuedAt.getTime());
    const maxPlausibleMeters = (elapsedMs / 1000) * ((MAX_PLAUSIBLE_SPEED_KMH * 1000) / 3600);
    // 음수(클라 글리치)는 0으로 흡수 — distance/sync와 동일. 컬럼도 >= 0 check 제약이 있음.
    const distanceAccumulatedMeters = Math.max(
      0,
      Math.floor(Math.min(claimedMeters, maxPlausibleMeters)),
    );

    // 부화했다고 주장(hatchedAt)하면서 정작 클램프된 누적 거리가 목표 미달인 자기모순 → 거부.
    if (egg.hatchedAt && distanceAccumulatedMeters < voucher.targetDistanceMeters) {
      eggResults.push({ id: egg.id, status: "rejected" });
      continue;
    }

    let eggRaceLost = false;
    try {
      // insert + voucher 삭제를 한 트랜잭션으로 — 둘 사이에서 함수가 죽으면 "알은 이관됐는데
      // voucher는 그대로"인 상태가 남아 cleanup 배치에 의존하게 됨(Document/temp.md 이슈 2).
      await db.transaction(async (tx) => {
        const inserted = await tx
          .insert(userEggs)
          .values({
            id: egg.id,
            userId: auth.sub,
            eggTypeId: voucher.eggTypeId,
            tourismSpotId: egg.tourismSpotId ?? null,
            targetDistanceMeters: voucher.targetDistanceMeters,
            distanceAccumulatedMeters,
            // isPartner는 서버에 없는 개념 — 파트너는 순수 기기 로컬 상태(Document/temp.md Part 1).
            // acquiredAt도 클라 값이 아니라 서버가 찍은 voucher.issuedAt으로 통일(위조 방지).
            acquiredAt: voucher.issuedAt,
            hatchedAt: egg.hatchedAt ? new Date(egg.hatchedAt) : null,
          })
          .onConflictDoNothing({ target: userEggs.id })
          .returning({ id: userEggs.id });
        if (inserted.length === 0) {
          // 동시 migrate 요청이 이 알을 먼저 넣음 — rejected가 아니라 already_done(Document/temp.md 이슈 3).
          eggRaceLost = true;
          return;
        }
        // insert가 실제로 성공한 뒤에만 voucher 삭제 — 같은 트랜잭션이라 원자적.
        await tx.delete(eggVouchers).where(eq(eggVouchers.id, egg.id));
      });
    } catch {
      eggResults.push({ id: egg.id, status: "rejected" });
      continue;
    }
    // voucher 매칭을 이미 통과했으므로 rarity는 확인된 값 — race든 신규든 몬스터 검증에 쓸 수 있음.
    verifiedEggRarity.set(egg.id, voucher.rarity);
    eggResults.push({ id: egg.id, status: eggRaceLost ? "already_done" : "migrated" });
  }

  // 몬스터 종 위조 검사(아래)용 정적 설정 — 루프 밖에서 한 번만 로드.
  const [allSpecies, allAttributeWeights, allRarityMultipliers] = await Promise.all([
    db.select({ id: monsterSpecies.id, attribute: monsterSpecies.attribute, rarity: monsterSpecies.rarity })
      .from(monsterSpecies),
    db.select({
      contentTypeId: monsterAttributeWeights.contentTypeId,
      monsterSpeciesId: monsterAttributeWeights.monsterSpeciesId,
      weight: monsterAttributeWeights.weight,
    }).from(monsterAttributeWeights),
    db.select({
      eggRarity: rarityWeightMultipliers.eggRarity,
      monsterRarity: rarityWeightMultipliers.monsterRarity,
      multiplier: rarityWeightMultipliers.multiplier,
    }).from(rarityWeightMultipliers),
  ]);
  const attributeWeights = allAttributeWeights.map((w) => ({
    contentTypeId: w.contentTypeId,
    monsterSpeciesId: w.monsterSpeciesId,
    weight: Number(w.weight),
  }));
  const rarityMultipliers = allRarityMultipliers.map((m) => ({
    eggRarity: m.eggRarity,
    monsterRarity: m.monsterRarity,
    multiplier: Number(m.multiplier),
  }));

  // (eggRarity, contentTypeId) 조합당 후보 종 집합은 같으므로 재계산하지 않고 캐시.
  const possibleSpeciesCache = new Map<string, Set<number>>();

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

    // 1차 후보(장소 content_type)를 위해 알의 spot을 서버가 직접 조회 — 클라 monster.tourismSpotId를
    // 믿고 후보 풀을 정하면 순환이 됨. eggId는 위 verifiedEggRarity 체크를 통과한 시점에서 본인
    // 소유 알로 확정.
    const [eggSpot] = await db
      .select({ contentTypeId: tourismSpots.contentTypeId })
      .from(userEggs)
      .leftJoin(tourismSpots, eq(userEggs.tourismSpotId, tourismSpots.id))
      .where(and(eq(userEggs.id, monster.eggId as string), eq(userEggs.userId, auth.sub)));

    // "이 알(등급) × 장소에서 determineMonster()가 실제로 내놓을 수 있는 종"에 클라가 주장한 종이
    // 들어있는지로 위조를 거름 — 지금까지는 rarity 배율 > 0만 봐서 epic 알로 아무 legendary나
    // claim할 수 있었음(Document/temp.md 이슈 5).
    const contentTypeId = eggSpot?.contentTypeId ?? null;
    const cacheKey = `${eggRarity}:${contentTypeId}`;
    let possible = possibleSpeciesCache.get(cacheKey);
    if (!possible) {
      possible = possibleMonsterSpeciesIds({
        eggRarity,
        contentTypeId,
        species: allSpecies,
        attributeWeights,
        rarityMultipliers,
      });
      possibleSpeciesCache.set(cacheKey, possible);
    }
    if (!possible.has(Number(monster.monsterSpeciesId))) {
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }

    let monsterRaceLost = false;
    try {
      // insert와 알 hatchedAt 갱신을 한 트랜잭션으로 묶음 — 둘 사이에서 함수가 죽으면 "몬스터
      // row는 있는데 알은 hatchedAt=null"로 남고, 그 알이 GET /api/eggs로 미부화 복구된 뒤
      // 재부화가 시도되면 user_monsters.egg_id UNIQUE 위반으로 hatch가 500이 나며 그 알이
      // 서버 경로로 영구 부화 불가가 됨(Document/temp.md 이슈 1).
      await db.transaction(async (tx) => {
        const inserted = await tx
          .insert(userMonsters)
          .values({
            id: monster.id,
            userId: auth.sub,
            monsterSpeciesId: Number(monster.monsterSpeciesId),
            eggId: monster.eggId,
            tourismSpotId: monster.tourismSpotId ?? null,
            hatchedAt: new Date(monster.hatchedAt),
          })
          .onConflictDoNothing({ target: userMonsters.id })
          .returning({ id: userMonsters.id });
        if (inserted.length === 0) {
          // 같은 몬스터를 동시 요청이 먼저 넣음 → already_done. egg_id UNIQUE 충돌은 target이
          // PK(id)라 여기서 안 걸리고 그대로 throw → 아래 catch → rejected(Document/temp.md 이슈 3).
          monsterRaceLost = true;
          return;
        }
        // 알이 먼저(미부화 상태로) 이관되고, 그 뒤 게스트로 로컬 부화한 몬스터가 다음 로그인에
        // 뒤늦게 도착하는 경우 — 알 row의 hatchedAt이 계속 null이면 복구(GET /api/eggs)가 이 알을
        // 미부화로 돌려주고 재부화가 시도되는 불일치가 생김. 몬스터가 붙는 순간 알도 부화 처리
        // (이미 값이 있으면 그대로 둠).
        if (monster.eggId) {
          await tx
            .update(userEggs)
            .set({ hatchedAt: new Date(monster.hatchedAt) })
            .where(
              and(
                eq(userEggs.id, monster.eggId),
                eq(userEggs.userId, auth.sub),
                isNull(userEggs.hatchedAt),
              ),
            );
        }
      });
    } catch {
      // eggId unique 제약 위반 포함 — 이미 다른 몬스터 row가 이 알을 소진했으면 거부.
      monsterResults.push({ id: monster.id, status: "rejected" });
      continue;
    }
    monsterResults.push({
      id: monster.id,
      status: monsterRaceLost ? "already_done" : "migrated",
    });
  }

  return Response.json({ eggs: eggResults, monsters: monsterResults });
}
