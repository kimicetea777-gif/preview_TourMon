// 마커 "더보기" 상세 조회 프록시 — detailCommon2(개요) + detailImage2(추가 사진).
// DB 캐싱 없음(4-5 섹션 원칙), 매 요청마다 TourAPI를 대신 호출. serviceKey는 서버에만 있음.
//
// 7단계 — ?locale=en 지원. KorService2/EngService2는 content_id 체계가 서로 달라서(scripts/
// tour-sync/sync.ts 상단 주석 참고) 국문 content_id를 그대로 영문 서비스에 넘기면 빈 결과만 옴 —
// scripts/tour-sync/eng-match.ts가 좌표 매칭으로 채워둔 tourism_spots.content_id_en이 있을 때만
// 영문 서비스를 호출하고, 없으면(매칭 실패/애매함으로 검토 대기) 국문 서비스로 폴백.
import { eq } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import { tourismSpots } from "@/db/schema";
import { resolveLocale } from "@/lib/locale";
import { fetchDetailCommon, fetchDetailImage } from "@/lib/tour-api";

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const { id } = await context.params;
  const spotId = Number(id);
  if (Number.isNaN(spotId)) {
    return Response.json({ error: "잘못된 id" }, { status: 400 });
  }

  const [spot] = await db
    .select({ contentId: tourismSpots.contentId, contentIdEn: tourismSpots.contentIdEn })
    .from(tourismSpots)
    .where(eq(tourismSpots.id, spotId));

  if (!spot) {
    return Response.json({ error: "해당 관광지를 찾을 수 없음" }, { status: 404 });
  }

  const wantsEnglish = resolveLocale(request) === "en" && spot.contentIdEn != null;
  const service = wantsEnglish ? ("eng" as const) : ("kor" as const);
  const contentId = wantsEnglish ? spot.contentIdEn! : spot.contentId;

  const [common, images] = await Promise.all([
    fetchDetailCommon({ service, contentId }),
    fetchDetailImage({ service, contentId }),
  ]);

  return Response.json({
    overview: common?.overview ?? null,
    homepage: common?.homepage ?? null,
    // en 요청이었는데 매칭된 영문 content가 없어 국문으로 폴백한 경우를 클라이언트가 구분할 수
    // 있게 알려줌 — 안 그러면 영어 화면에 한국어 설명이 아무 표시 없이 섞여 나옴(실기기 확인).
    usedEnglish: wantsEnglish,
    images: images.items.map((img) => ({
      originImgUrl: img.originimgurl,
      smallImageUrl: img.smallimageurl ?? img.originimgurl,
      cpyrhtDivCd: img.cpyrhtDivCd ?? null,
    })),
  });
}
