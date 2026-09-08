// 앱 최초 설치 웰컴 알 — 위치/인증 없이 common 알 1개를 egg_vouchers로 발급한다. 응답 shape은
// /api/eggs/acquire와 동일(voucher.id 기반)하고, 클라이언트는 그 id를 로컬 user_eggs.id로 그대로
// 써서 나중에 게스트→회원 마이그레이션 대조가 맞는다 — 즉 "스팟에서 받은 일반 게스트 알"과
// 구조적으로 동일하고, migrate/hatch/도감 경로에 특수 처리가 하나도 안 붙는다(Document/temp.md
// "앱 설치 웰컴 알" 참고). acquire에서 스팟/반경/쿨타임/user_eggs insert만 뺀 축소본.
//
// 인증하지 않는 이유: 지금은 "게스트 전용 출시" 모드라 로그인 유저가 없고, 웰컴 라우트는 acquire와
// 달리 user_eggs row를 만들지 않으므로(로그인 상태여도 voucher만 발급 → 다음 migrateIfNeeded가
// 흡수) auth 분기가 필요 없다. 재설치 파밍은 허용(WELCOME_EGG_RARITY 주석 참고).
import { and, eq, inArray } from "drizzle-orm";
import { v7 as uuidv7 } from "uuid";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { eggTypeTranslations, eggTypes, eggVouchers } from "@/db/schema";
import { WELCOME_EGG_RARITY } from "@/lib/game-config";
import { localesToFetch, pickTranslation, resolveLocale } from "@/lib/locale";

export async function POST(request: NextRequest) {
  const locale = resolveLocale(request);

  const commonEggTypes = await db
    .select()
    .from(eggTypes)
    .where(and(eq(eggTypes.isActive, true), eq(eggTypes.rarity, WELCOME_EGG_RARITY)));

  if (commonEggTypes.length === 0) {
    return Response.json({ error: "활성화된 common 알 종류가 없음" }, { status: 500 });
  }

  // common 종류가 여럿이면 그 안에서 weight로 롤(acquire와 동일한 방식). 하나뿐이면 그대로 선택됨.
  const totalWeight = commonEggTypes.reduce((sum, e) => sum + Number(e.weight), 0);
  let roll = Math.random() * totalWeight;
  let chosen = commonEggTypes[commonEggTypes.length - 1];
  for (const eggType of commonEggTypes) {
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

  // acquire와 동일 — 로그인 여부와 무관하게 항상 voucher 발급. 클라이언트는 이 id를 로컬
  // user_eggs.id로 그대로 쓴다.
  const id = uuidv7();
  await db.insert(eggVouchers).values({
    id,
    eggTypeId: chosen.id,
    rarity: chosen.rarity,
    targetDistanceMeters: chosen.targetDistanceMeters,
  });

  return Response.json({
    id,
    eggTypeId: chosen.id,
    rarity: chosen.rarity,
    targetDistanceMeters: chosen.targetDistanceMeters,
    name: translation?.name ?? chosen.rarity,
    description: translation?.description ?? null,
  });
}
