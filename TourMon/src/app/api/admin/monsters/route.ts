// 어드민 몬스터 추가 — monster_species(+ko/en 번역) row 생성. attribute는 현재 게임 로직에서 실제로
// 안 쓰임(2026-08-26 결정, scripts/seed.ts 주석 참고 — 부화 확률은 monster_attribute_weights가
// contentType×species 단위로 직접 매김) — NOT NULL이라 폼에는 남겨두되 값 자체는 확률에 영향 없음.
//
// monster_attribute_weights에 이 종의 행이 하나도 없으면 부화 결정 로직(monster-determination.ts의
// monsterPool())이 이 종을 절대 뽑지 못한다 — 이미 다른 종들이 모든 content_type에 가중치 행을
// 갖고 있어서(seed.ts) "행이 하나도 없을 때만 균등 폴백" 규칙이 새 종에는 적용 안 되기 때문. 그래서
// 기존 seed.ts와 동일하게 모든 content_type에 대해 weight=1 행을 같이 만들어야 새 몬스터가 실제로
// 출현한다.
import { inArray } from "drizzle-orm";
import type { NextRequest } from "next/server";
import { db } from "@/db";
import {
  contentTypes,
  monsterAttributeEnum,
  monsterAttributeWeights,
  monsterSpecies,
  monsterSpeciesTranslations,
  rarityTierEnum,
} from "@/db/schema";
import { ADMIN_BASE_URL, requireAdminSession } from "@/lib/admin/server-session";
import { isUniqueViolation } from "@/lib/db-errors";
import { monsterArtUrls } from "@/lib/monster-art";
import { invalidateMonsterConfigCache } from "@/lib/monster-config-cache";

function redirectToList(origin: string, params: Record<string, string>): Response {
  const url = new URL("/admin/monsters", origin);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value);
  return Response.redirect(url, 303);
}

// 에러 시엔 add=1도 같이 실어 보내 목록 페이지가 "몬스터 추가" 팝업을 다시 열어둔 채로 에러를 보여준다.
function redirectToListError(origin: string, error: string): Response {
  return redirectToList(origin, { error, add: "1" });
}

// 빈 값 → null(정상, 미입력), 양의 정수 → 그 값, 그 외(음수/소수/문자 등) → undefined(형식 오류).
function parseOptionalPositiveInt(value: FormDataEntryValue | null): number | null | undefined {
  if (value == null || value === "") return null;
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : undefined;
}

export async function POST(request: NextRequest) {
  const auth = await requireAdminSession();
  if (!auth) return Response.json({ error: "관리자 권한 필요" }, { status: 403 });

  const origin = ADMIN_BASE_URL;
  const form = await request.formData();

  const dexNumber = Number(form.get("dexNumber"));
  const rarity = form.get("rarity")?.toString();
  const attribute = form.get("attribute")?.toString();
  const nameKo = form.get("nameKo")?.toString().trim();
  const nameEn = form.get("nameEn")?.toString().trim();
  const descriptionKo = form.get("descriptionKo")?.toString().trim() || null;
  const descriptionEn = form.get("descriptionEn")?.toString().trim() || null;

  if (!Number.isInteger(dexNumber) || dexNumber <= 0) {
    return redirectToListError(origin, "invalid_dex_number");
  }
  if (!rarity || !(rarityTierEnum.enumValues as readonly string[]).includes(rarity)) {
    return redirectToListError(origin, "invalid_rarity");
  }
  if (!attribute || !(monsterAttributeEnum.enumValues as readonly string[]).includes(attribute)) {
    return redirectToListError(origin, "invalid_attribute");
  }
  if (!nameKo || !nameEn) {
    return redirectToListError(origin, "name_required");
  }

  const evolvesFromId = parseOptionalPositiveInt(form.get("evolvesFromId"));
  const evolvesToId = parseOptionalPositiveInt(form.get("evolvesToId"));
  const evolutionStage = parseOptionalPositiveInt(form.get("evolutionStage"));
  if (evolvesFromId === undefined || evolvesToId === undefined || evolutionStage === undefined) {
    return redirectToListError(origin, "invalid_evolution_field");
  }

  const referencedSpeciesIds = [evolvesFromId, evolvesToId].filter((id): id is number => id !== null);
  if (referencedSpeciesIds.length > 0) {
    const existing = await db
      .select({ id: monsterSpecies.id })
      .from(monsterSpecies)
      .where(inArray(monsterSpecies.id, referencedSpeciesIds));
    if (existing.length !== new Set(referencedSpeciesIds).size) {
      return redirectToListError(origin, "evolution_reference_not_found");
    }
  }

  const { imageUrl, animationUrl } = monsterArtUrls(dexNumber);

  try {
    await db.transaction(async (tx) => {
      const [species] = await tx
        .insert(monsterSpecies)
        .values({
          dexNumber,
          attribute: attribute as (typeof monsterAttributeEnum.enumValues)[number],
          rarity: rarity as (typeof rarityTierEnum.enumValues)[number],
          imageUrl,
          animationUrl,
          evolvesFromId,
          evolvesToId,
          evolutionStage,
        })
        .returning({ id: monsterSpecies.id });

      await tx.insert(monsterSpeciesTranslations).values([
        { monsterSpeciesId: species.id, locale: "ko", name: nameKo, description: descriptionKo },
        { monsterSpeciesId: species.id, locale: "en", name: nameEn, description: descriptionEn },
      ]);

      // 모든 관광지 유형에 균등 가중치(1)로 배정 — scripts/seed.ts의 기존 placeholder 배정과 동일한
      // 규칙(파일 상단 주석 참고). 나중에 장소별 가중치를 실제로 조정하는 기능이 생기면 그때 값만
      // 바꾸면 됨(코드 변경 불필요).
      const allContentTypes = await tx.select({ id: contentTypes.id }).from(contentTypes);
      if (allContentTypes.length > 0) {
        await tx.insert(monsterAttributeWeights).values(
          allContentTypes.map((ct) => ({
            contentTypeId: ct.id,
            monsterSpeciesId: species.id,
            weight: "1",
          })),
        );
      }
    });
  } catch (err) {
    if (isUniqueViolation(err)) {
      return redirectToListError(origin, "dex_number_taken");
    }
    throw err;
  }

  invalidateMonsterConfigCache();
  return redirectToList(origin, { success: "1" });
}
