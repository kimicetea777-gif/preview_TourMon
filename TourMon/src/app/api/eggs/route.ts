// 6단계 Phase 5 — 알 보관함 복구(restore). 로그인 계정으로 새 기기/재설치 후에도 서버에 남아있는
// 미부화 알을 되찾아올 수 있어야 "로그인 = 데이터가 서버에 남는다"는 약속이 저장(migrate/hatch)
// 뿐 아니라 복구까지 완성됨(Document/study_folder/6-5_... 참고). 부화 완료된 알은 이미
// user_monsters로 대표되므로 제외 — 보관함 화면이 실제로 필요로 하는 건 미부화 알뿐.
import { and, eq, inArray, isNull } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { eggTypeTranslations, eggTypes, tourismSpots, userEggs } from "@/db/schema";
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
        id: userEggs.id,
        eggTypeId: userEggs.eggTypeId,
        rarity: eggTypes.rarity,
        tourismSpotId: userEggs.tourismSpotId,
        tourismSpotTitle: tourismSpots.title,
        contentTypeId: tourismSpots.contentTypeId,
        targetSteps: userEggs.targetSteps,
        stepsAccumulated: userEggs.stepsAccumulated,
        isPartner: userEggs.isPartner,
        acquiredAt: userEggs.acquiredAt,
      })
      .from(userEggs)
      .innerJoin(eggTypes, eq(userEggs.eggTypeId, eggTypes.id))
      .leftJoin(tourismSpots, eq(userEggs.tourismSpotId, tourismSpots.id))
      .where(and(eq(userEggs.userId, auth.sub), isNull(userEggs.hatchedAt))),
    db
      .select()
      .from(eggTypeTranslations)
      .where(inArray(eggTypeTranslations.locale, localesToFetch(locale))),
  ]);

  const translationsByEggTypeId = new Map<number, typeof translationRows>();
  for (const t of translationRows) {
    const list = translationsByEggTypeId.get(t.eggTypeId) ?? [];
    list.push(t);
    translationsByEggTypeId.set(t.eggTypeId, list);
  }

  return Response.json({
    eggs: rows.map((r) => {
      const translation = pickTranslation(translationsByEggTypeId.get(r.eggTypeId) ?? [], locale);
      return {
        id: r.id,
        eggTypeId: r.eggTypeId,
        rarity: r.rarity,
        tourismSpotId: r.tourismSpotId,
        tourismSpotTitle: r.tourismSpotTitle,
        contentTypeId: r.contentTypeId,
        targetSteps: r.targetSteps,
        stepsAccumulated: r.stepsAccumulated,
        isPartner: r.isPartner,
        acquiredAt: r.acquiredAt,
        name: translation?.name ?? r.rarity,
        description: translation?.description ?? null,
      };
    }),
  });
}
