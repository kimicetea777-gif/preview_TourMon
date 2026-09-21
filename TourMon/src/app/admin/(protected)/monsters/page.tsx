import { asc } from "drizzle-orm";
import Link from "next/link";
import { db } from "@/db";
import {
  monsterAttributeEnum,
  monsterSpecies,
  monsterSpeciesTranslations,
  rarityTierEnum,
} from "@/db/schema";
import styles from "./monsters.module.css";

const ERROR_MESSAGES: Record<string, string> = {
  invalid_dex_number: "도감 번호는 1 이상의 정수여야 합니다.",
  invalid_rarity: "희귀도 값이 올바르지 않습니다.",
  invalid_attribute: "속성 값이 올바르지 않습니다.",
  name_required: "한국어/영어 이름은 필수입니다.",
  invalid_evolution_field: "진화 관련 입력값은 1 이상의 정수여야 합니다.",
  evolution_reference_not_found: "진화 전/후 몬스터 id가 존재하지 않습니다.",
  dex_number_taken: "이미 사용 중인 도감 번호입니다.",
};

const RARITY_BADGE_CLASS: Record<string, string> = {
  common: styles.badgeCommon,
  rare: styles.badgeRare,
  epic: styles.badgeEpic,
  legendary: styles.badgeLegendary,
};

const ATTRIBUTE_DOT_COLOR: Record<string, string> = {
  grass: "#22c55e",
  water: "#3b82f6",
  fire: "#f97316",
  psychic: "#ec4899",
  ghost: "#6366f1",
};

type SearchParams = Promise<{ success?: string; error?: string; rarity?: string; q?: string; add?: string }>;

function buildListHref(rarity: string | undefined, q: string | undefined, add?: boolean): string {
  const params = new URLSearchParams();
  if (rarity) params.set("rarity", rarity);
  if (q) params.set("q", q);
  if (add) params.set("add", "1");
  const qs = params.toString();
  return qs ? `/admin/monsters?${qs}` : "/admin/monsters";
}

export default async function AdminMonstersPage({ searchParams }: { searchParams: SearchParams }) {
  const { success, error, rarity: rawRarity, q: rawQ, add } = await searchParams;
  const rarity = rawRarity && (rarityTierEnum.enumValues as readonly string[]).includes(rawRarity) ? rawRarity : undefined;
  const q = rawQ?.trim() || undefined;
  const addOpen = add === "1";

  const [species, translations] = await Promise.all([
    db.select().from(monsterSpecies).orderBy(asc(monsterSpecies.dexNumber)),
    db.select().from(monsterSpeciesTranslations),
  ]);
  const koNameById = new Map(
    translations.filter((t) => t.locale === "ko").map((t) => [t.monsterSpeciesId, t.name]),
  );
  const enSpeciesIds = new Set(translations.filter((t) => t.locale === "en").map((t) => t.monsterSpeciesId));
  const dexById = new Map(species.map((s) => [s.id, s.dexNumber]));

  const rarityCounts = new Map<string, number>();
  let evolutionChainCount = 0;
  for (const s of species) {
    rarityCounts.set(s.rarity, (rarityCounts.get(s.rarity) ?? 0) + 1);
    if (s.evolvesFromId || s.evolvesToId) evolutionChainCount += 1;
  }
  const missingEnCount = species.filter((s) => !enSpeciesIds.has(s.id)).length;

  const filtered = species.filter((s) => {
    if (rarity && s.rarity !== rarity) return false;
    if (q) {
      const name = koNameById.get(s.id) ?? "";
      const needle = q.toLowerCase();
      if (!name.toLowerCase().includes(needle) && !String(s.dexNumber).includes(needle)) return false;
    }
    return true;
  });

  return (
    <div className={styles.page}>
      <div className={styles.headerRow}>
        <div>
          <p className={styles.eyebrow}>관리자 콘솔 / 몬스터</p>
          <h1 className={styles.title}>몬스터</h1>
          <p className={styles.subtitle}>몬스터 도감 목록을 보고 새 몬스터를 추가합니다.</p>
        </div>
        <Link href={buildListHref(rarity, q, true)} className={styles.headerActionButton}>
          몬스터 추가
        </Link>
      </div>

      {success && <p className={styles.bannerSuccess}>몬스터를 추가했습니다.</p>}
      {error && !addOpen && <p className={styles.bannerError}>{ERROR_MESSAGES[error] ?? `오류: ${error}`}</p>}

      <section className={styles.kpiGrid}>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>전체 몬스터</span>
          <span className={styles.kpiValue}>{species.length}종</span>
          <span className={styles.kpiSub}>
            {species.length > 0 ? `#${species[0].dexNumber} ~ #${species[species.length - 1].dexNumber}` : "등록된 몬스터 없음"}
          </span>
        </div>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>등급별 분포</span>
          <div className={styles.kpiBreakdown}>
            {rarityTierEnum.enumValues.map((r) => (
              <span key={r}>
                {r} {rarityCounts.get(r) ?? 0}
              </span>
            ))}
          </div>
        </div>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>진화 체인 보유</span>
          <span className={styles.kpiValue}>{evolutionChainCount}종</span>
          <span className={styles.kpiSub}>진화 전/후 관계가 있는 몬스터</span>
        </div>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>영어 번역 누락</span>
          <span className={styles.kpiValue}>{missingEnCount}종</span>
          <span className={styles.kpiSub}>en 번역 행이 없는 몬스터</span>
        </div>
      </section>

      <section className={styles.toolbar}>
        <div className={styles.tabs}>
          <Link href={buildListHref(undefined, q)} className={`${styles.tab} ${!rarity ? styles.tabActive : ""}`}>
            전체 ({species.length})
          </Link>
          {rarityTierEnum.enumValues.map((r) => (
            <Link
              key={r}
              href={buildListHref(r, q)}
              className={`${styles.tab} ${rarity === r ? styles.tabActive : ""}`}
            >
              {r} ({rarityCounts.get(r) ?? 0})
            </Link>
          ))}
        </div>
        <form action="/admin/monsters" method="get" className={styles.searchForm}>
          {rarity && <input type="hidden" name="rarity" value={rarity} />}
          <input
            type="text"
            name="q"
            defaultValue={q ?? ""}
            placeholder="이름 또는 도감 번호 검색"
            className={styles.searchInput}
          />
          <button type="submit" className={styles.searchButton}>
            검색
          </button>
        </form>
      </section>

      <div className={styles.tableCard}>
        <div className={styles.tableHeaderStrip}>
          <span>몬스터 목록</span>
          <span>
            {filtered.length}종 표시 중 (전체 {species.length}종)
          </span>
        </div>
        <div className={styles.tableScroll}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>#</th>
                <th>몬스터</th>
                <th>희귀도</th>
                <th>속성</th>
                <th>진화</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((s) => (
                <tr key={s.id}>
                  <td className={styles.dexCell}>#{s.dexNumber}</td>
                  <td>
                    <div className={styles.monsterCell}>
                      {/* eslint-disable-next-line @next/next/no-img-element -- 외부 CDN 썸네일, next/image remotePatterns 설정 없이 확인용 */}
                      <img src={s.imageUrl} alt="" className={styles.thumb} />
                      <div>
                        <div className={styles.monsterName}>{koNameById.get(s.id) ?? "-"}</div>
                        {!enSpeciesIds.has(s.id) && <div className={styles.monsterMeta}>en 번역 없음</div>}
                      </div>
                    </div>
                  </td>
                  <td>
                    <span className={`${styles.badge} ${RARITY_BADGE_CLASS[s.rarity] ?? ""}`}>{s.rarity}</span>
                  </td>
                  <td>
                    <span className={styles.attributeChip}>
                      <span
                        className={styles.attributeDot}
                        style={{ background: ATTRIBUTE_DOT_COLOR[s.attribute] ?? "#9ca3af" }}
                      />
                      {s.attribute}
                    </span>
                  </td>
                  <td className={styles.evoChain}>
                    {s.evolvesFromId ? `#${dexById.get(s.evolvesFromId) ?? s.evolvesFromId} → ` : ""}
                    {s.evolvesToId ? `→ #${dexById.get(s.evolvesToId) ?? s.evolvesToId}` : ""}
                    {!s.evolvesFromId && !s.evolvesToId && "-"}
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={5}>
                    <div className={styles.emptyState}>조건에 맞는 몬스터가 없습니다.</div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {addOpen && (
        <div className={styles.modalOverlay}>
          <Link href={buildListHref(rarity, q)} className={styles.modalBackdrop} aria-label="닫기" />
          <div className={`${styles.formCard} ${styles.modalCard}`}>
            <div className={styles.modalHeader}>
              <h2>몬스터 추가</h2>
              <Link href={buildListHref(rarity, q)} className={styles.modalCloseButton} aria-label="닫기">
                ✕
              </Link>
            </div>
            {error && <p className={styles.bannerError}>{ERROR_MESSAGES[error] ?? `오류: ${error}`}</p>}
            <form action="/api/admin/monsters" method="post">
              <label className={styles.field}>
                도감 번호
                <input type="number" name="dexNumber" min={1} required />
              </label>
              <div className={styles.fieldRow}>
                <label className={styles.field}>
                  희귀도
                  <select name="rarity" required defaultValue="common">
                    {rarityTierEnum.enumValues.map((r) => (
                      <option key={r} value={r}>
                        {r}
                      </option>
                    ))}
                  </select>
                </label>
                <label className={styles.field}>
                  속성
                  <select name="attribute" required defaultValue={monsterAttributeEnum.enumValues[0]}>
                    {monsterAttributeEnum.enumValues.map((a) => (
                      <option key={a} value={a}>
                        {a}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              <label className={styles.field}>
                이름 (ko)
                <input type="text" name="nameKo" required />
              </label>
              <label className={styles.field}>
                설명 (ko)
                <textarea name="descriptionKo" rows={2} />
              </label>
              <label className={styles.field}>
                이름 (en)
                <input type="text" name="nameEn" required />
              </label>
              <label className={styles.field}>
                설명 (en)
                <textarea name="descriptionEn" rows={2} />
              </label>
              <div className={styles.fieldRow}>
                <label className={styles.field}>
                  진화 전 id (선택)
                  <input type="number" name="evolvesFromId" min={1} />
                </label>
                <label className={styles.field}>
                  진화 후 id (선택)
                  <input type="number" name="evolvesToId" min={1} />
                </label>
              </div>
              <label className={styles.field}>
                진화 단계 (선택)
                <input type="number" name="evolutionStage" min={1} />
              </label>
              <p className={styles.hint}>
                이미지/애니메이션 URL은 도감 번호로 자동 계산됩니다 — 먼저 개발 PC에서{" "}
                <code>Resource/Img/</code>에 <code>049_img_*.png</code>(2048², 정적),{" "}
                <code>Resource/Ani/</code>에 <code>049_ani_*.png</code>(480², APNG) 형식으로 새 몬스터
                파일을 넣고(파일명 맨 앞 3자리 숫자가 도감 번호) <code>npm run monster-art:upload</code>를
                실행해 해당 번호의 아트를 R2에 올려야 썸네일이 보입니다.
              </p>
              <button type="submit" className={styles.submitButton}>
                추가
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
