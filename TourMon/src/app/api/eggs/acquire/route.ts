// 3단계 — 알 획득 판정. 위치 검증 + egg_type 확률 배정은 게스트/로그인 공통.
// 6단계 Phase 4(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md)부터: 로그인 여부와 무관하게 매번 egg_vouchers(무기명
// 발급 확인증)를 생성해 응답 id로 내려줌 — 게스트→회원 마이그레이션 시 이 id로 위조 여부를 대조함
// (init_plan.md DB 스키마 섹션 egg_vouchers 참고). 로그인 상태면 추가로 서버 쿨타임을 먼저 체크하고
// user_eggs row까지 직접 insert함 — 게스트는 여전히 결과를 로컬 SQLite에만 저장(egg_repository.dart).
import { and, eq, inArray, sql } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { contentTypes, eggTypeTranslations, eggTypes, eggVouchers, tourismSpots, userEggs } from "@/db/schema";
import { verifyAccessToken } from "@/lib/auth";
import { DAILY_RESET_HOUR_KST, EGG_ACQUISITION_RADIUS_METERS } from "@/lib/game-config";
import { localesToFetch, pickTranslation, resolveLocale } from "@/lib/locale";

export async function POST(request: NextRequest) {
  const locale = resolveLocale(request);
  const body = await request.json().catch(() => null);
  const tourismSpotId = Number(body?.tourismSpotId);
  const lat = Number(body?.lat);
  const lng = Number(body?.lng);

  if (Number.isNaN(tourismSpotId) || Number.isNaN(lat) || Number.isNaN(lng)) {
    return Response.json(
      { error: "tourismSpotId, lat, lng가 모두 필요함" },
      { status: 400 },
    );
  }

  const auth = await verifyAccessToken(request);

  const [spot] = await db
    .select({
      id: tourismSpots.id,
      representativeSpotId: tourismSpots.representativeSpotId,
      eggAcquisitionEnabled: contentTypes.eggAcquisitionEnabled,
      withinRadius: sql<boolean>`ST_DWithin(${tourismSpots.locationGeog}, ST_MakePoint(${lng}, ${lat})::geography, ${EGG_ACQUISITION_RADIUS_METERS})`,
    })
    .from(tourismSpots)
    .innerJoin(contentTypes, eq(contentTypes.id, tourismSpots.contentTypeId))
    .where(and(eq(tourismSpots.id, tourismSpotId), eq(tourismSpots.isActive, true)));

  if (!spot) {
    return Response.json({ error: "해당 관광지를 찾을 수 없음" }, { status: 404 });
  }
  // 클라이언트도 버튼을 비활성화해두지만(숙박/음식점/쇼핑), 그건 UX일 뿐이라 실제 차단은 여기서 —
  // 위치 검증보다 먼저 체크해서 "여기 서 있어도 애초에 못 받는 유형"임을 더 정확히 알려줌.
  if (!spot.eggAcquisitionEnabled) {
    return Response.json({ error: "이 관광지 유형은 알을 획득할 수 없음" }, { status: 403 });
  }
  if (!spot.withinRadius) {
    return Response.json({ error: "위치 확인 안 됨" }, { status: 422 });
  }

  // 좌표 중복(같은 건물 내 여러 매장) 그룹에서는 쿨타임/보관을 개별 spot이 아니라 대표 spot 기준으로
  // 묶음(Document/temp.md "관광지 마커 — 좌표 중복" 결정 배경) — 클라이언트가 어떤 tourismSpotId를 보내든
  // 서버가 무조건 대표로 정규화해서, 유저가 리스트에서 항목을 매일 갈아타며 쿨타임을 우회하는 걸
  // 원천 차단함(radius 검증 자체는 유저가 실제로 서 있는 tourismSpotId 좌표 기준 그대로 둠).
  const cooldownSpotId = spot.representativeSpotId ?? spot.id;

  const sameKstResetDay = sql`date_trunc('day', (${userEggs.acquiredAt} AT TIME ZONE 'Asia/Seoul') - interval '${sql.raw(String(DAILY_RESET_HOUR_KST))} hours') = date_trunc('day', (now() AT TIME ZONE 'Asia/Seoul') - interval '${sql.raw(String(DAILY_RESET_HOUR_KST))} hours')`;

  // 로그인 상태면 egg_type을 굴리기 전에 서버 쿨타임부터 먼저 확인(best-effort) — 순서가 반대면
  // 쿨타임에 걸릴 요청도 egg_type 롤+voucher 생성까지 다 해놓고 마지막에 거부돼서, 아무도 못 쓸
  // voucher만 낭비로 쌓임. "하루" 경계는 KST 새벽 4시(DAILY_RESET_HOUR_KST) 고정.
  // ⚠️ 이 시점의 체크는 잠금 없이 하는 사전 확인일 뿐 — 진짜 판정은 아래 트랜잭션 안에서 다시 함
  // (동시에 같은 스팟에 두 번 요청이 들어오면 이 체크만으로는 둘 다 통과해버리는 race가 있음).
  if (auth) {
    const [existing] = await db
      .select({ id: userEggs.id })
      .from(userEggs)
      .where(
        and(
          eq(userEggs.userId, auth.sub),
          eq(userEggs.tourismSpotId, cooldownSpotId),
          sameKstResetDay,
        ),
      )
      .limit(1);
    if (existing) {
      return Response.json({ error: "오늘은 이미 이 관광지에서 알을 받았음" }, { status: 409 });
    }
  }

  const activeEggTypes = await db
    .select()
    .from(eggTypes)
    .where(eq(eggTypes.isActive, true));

  if (activeEggTypes.length === 0) {
    return Response.json({ error: "활성화된 알 종류가 없음" }, { status: 500 });
  }

  const totalWeight = activeEggTypes.reduce((sum, e) => sum + Number(e.weight), 0);
  let roll = Math.random() * totalWeight;
  let chosen = activeEggTypes[activeEggTypes.length - 1];
  for (const eggType of activeEggTypes) {
    if (roll < Number(eggType.weight)) {
      chosen = eggType;
      break;
    }
    roll -= Number(eggType.weight);
  }

  const translationRows = await db
    .select()
    .from(eggTypeTranslations)
    .where(
      and(
        eq(eggTypeTranslations.eggTypeId, chosen.id),
        inArray(eggTypeTranslations.locale, localesToFetch(locale)),
      ),
    );
  const translation = pickTranslation(translationRows, locale);

  // 로그인 여부와 무관하게 항상 voucher 발급 — 게스트가 나중에 회원가입할 때 이 id로 위조 여부를
  // 대조하므로, 여기서 건너뛰면 마이그레이션이 항상 실패함(init_plan.md 403줄 원 설계에 로그인
  // 조건이 없는 이유). 클라이언트는 게스트/로그인 구분 없이 이 id를 로컬 user_eggs.id로 그대로 씀.
  const id = uuidv7();
  await db.insert(eggVouchers).values({
    id,
    eggTypeId: chosen.id,
    rarity: chosen.rarity,
    targetSteps: chosen.targetSteps,
  });

  // 로그인 상태면 실제 인벤토리 row도 바로 생성 — voucher와는 별개(voucher는 마이그레이션 없이도
  // 바로 게임 진행 가능하도록 여기서 삭제하지 않고 그대로 둠).
  // ⚠️ 위의 사전 쿨타임 체크와 이 insert 사이에 동시에 들어온 두 번째 요청이 끼어들면 같은 날 두 개의
  // 알이 발급될 수 있음(check-then-act race) — 그래서 여기서 세션 스코프 advisory lock으로
  // (userId, tourismSpotId) 조합을 잠그고 트랜잭션 안에서 쿨타임을 한 번 더(authoritative하게)
  // 확인한 뒤에만 insert함. 락은 트랜잭션 커밋/롤백 시 자동 해제되므로 별도 해제 코드 불필요.
  if (auth) {
    const insertedOrBlocked = await db.transaction(async (tx) => {
      await tx.execute(sql`SELECT pg_advisory_xact_lock(hashtext(${auth.sub}), ${cooldownSpotId})`);

      const [stillFree] = await tx
        .select({ id: userEggs.id })
        .from(userEggs)
        .where(
          and(
            eq(userEggs.userId, auth.sub),
            eq(userEggs.tourismSpotId, cooldownSpotId),
            sameKstResetDay,
          ),
        )
        .limit(1);
      if (stillFree) return false;

      await tx.insert(userEggs).values({
        id,
        userId: auth.sub,
        eggTypeId: chosen.id,
        tourismSpotId: cooldownSpotId,
        targetSteps: chosen.targetSteps,
      });
      return true;
    });

    if (!insertedOrBlocked) {
      // 방금 만든 voucher는 그대로 둠(무기명이라 나중에 다른 획득 시도에서 쓰일 일은 없지만, 삭제
      // 없이도 90일 TTL 정리가 자연히 처리함 — init_plan.md egg_vouchers TTL 설계와 동일한 결).
      return Response.json({ error: "오늘은 이미 이 관광지에서 알을 받았음" }, { status: 409 });
    }
  }

  return Response.json({
    id,
    eggTypeId: chosen.id,
    rarity: chosen.rarity,
    targetSteps: chosen.targetSteps,
    name: translation?.name ?? chosen.rarity,
    description: translation?.description ?? null,
  });
}
