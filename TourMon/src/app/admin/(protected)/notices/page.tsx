import { asc, eq } from "drizzle-orm";
import Link from "next/link";
import { db } from "@/db";
import { appNoticeTranslations, appNotices, noticeLevelEnum } from "@/db/schema";
import styles from "./notices.module.css";

const ERROR_MESSAGES: Record<string, string> = {
  invalid_level: "레벨 값이 올바르지 않습니다.",
  text_required: "한국어/영어 제목·본문은 모두 필수입니다.",
  invalid_url: "링크는 https URL이어야 합니다.",
  invalid_date: "시작/종료 일시 형식이 올바르지 않습니다.",
  date_range_invalid: "시작 일시가 종료 일시보다 늦습니다.",
  invalid_id: "잘못된 공지 id입니다.",
  publish_failed: "DB에는 저장됐지만 R2 게시에 실패했습니다 — 다른 공지를 추가/삭제하면 그때 다시 게시를 시도합니다.",
};

const LEVEL_LABEL: Record<string, string> = {
  info: "정보",
  warn: "경고",
  critical: "긴급",
};

const LEVEL_BADGE_CLASS: Record<string, string> = {
  info: styles.badgeInfo,
  warn: styles.badgeWarn,
  critical: styles.badgeCritical,
};

type SearchParams = Promise<{ success?: string; error?: string; detail?: string; add?: string }>;

function buildListHref(add?: boolean): string {
  return add ? "/admin/notices?add=1" : "/admin/notices";
}

export default async function AdminNoticesPage({ searchParams }: { searchParams: SearchParams }) {
  const { success, error, detail, add } = await searchParams;
  const addOpen = add === "1";

  const [notices, koTranslations] = await Promise.all([
    db.select().from(appNotices).orderBy(asc(appNotices.createdAt)),
    db.select().from(appNoticeTranslations).where(eq(appNoticeTranslations.locale, "ko")),
  ]);
  const koTitleById = new Map(koTranslations.map((t) => [t.noticeId, t.title]));

  const now = Date.now();
  const activeCount = notices.filter((n) => {
    const startsOk = !n.startsAt || n.startsAt.getTime() <= now;
    const endsOk = !n.endsAt || n.endsAt.getTime() >= now;
    return startsOk && endsOk;
  }).length;

  const levelCounts = new Map<string, number>();
  for (const n of notices) levelCounts.set(n.level, (levelCounts.get(n.level) ?? 0) + 1);

  return (
    <div className={styles.page}>
      <div className={styles.headerRow}>
        <div>
          <p className={styles.eyebrow}>관리자 콘솔 / 공지</p>
          <h1 className={styles.title}>공지</h1>
          <p className={styles.subtitle}>
            저장하면 바로 R2에 게시됩니다(최대 60초 뒤 앱에 반영). 강제 업데이트 게이트(최소 지원 빌드 등)는
            여기서 다루지 않습니다 — <code>scripts/app-notice.json</code> + <code>npm run notice:publish</code>로
            별도 관리됩니다.
          </p>
        </div>
        <Link href={buildListHref(true)} className={styles.headerActionButton}>
          공지 추가
        </Link>
      </div>

      {success === "1" && <p className={styles.bannerSuccess}>공지를 추가하고 게시했습니다.</p>}
      {success === "deleted" && <p className={styles.bannerSuccess}>공지를 삭제하고 다시 게시했습니다.</p>}
      {error && !addOpen && (
        <p className={styles.bannerError}>
          {ERROR_MESSAGES[error] ?? `오류: ${error}`}
          {detail && ` (${detail})`}
        </p>
      )}

      <section className={styles.kpiGrid}>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>전체 공지</span>
          <span className={styles.kpiValue}>{notices.length}건</span>
        </div>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>현재 노출 기간</span>
          <span className={styles.kpiValue}>{activeCount}건</span>
          <span className={styles.kpiSub}>시작/종료 일시 기준</span>
        </div>
        <div className={styles.kpiCard}>
          <span className={styles.kpiLabel}>레벨별 분포</span>
          <div className={styles.kpiBreakdown}>
            {noticeLevelEnum.enumValues.map((l) => (
              <span key={l}>
                {LEVEL_LABEL[l] ?? l} {levelCounts.get(l) ?? 0}
              </span>
            ))}
          </div>
        </div>
      </section>

      <div className={styles.tableCard}>
        <div className={styles.tableHeaderStrip}>
          <span>공지 목록</span>
          <span>{notices.length}건</span>
        </div>
        <div className={styles.tableScroll}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>레벨</th>
                <th>제목(ko)</th>
                <th>기간</th>
                <th>링크</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {notices.map((n) => (
                <tr key={n.id}>
                  <td>
                    <span className={`${styles.badge} ${LEVEL_BADGE_CLASS[n.level] ?? ""}`}>
                      {LEVEL_LABEL[n.level] ?? n.level}
                    </span>
                  </td>
                  <td className={styles.titleCell}>{koTitleById.get(n.id) ?? "-"}</td>
                  <td className={styles.periodCell}>
                    {n.startsAt ? new Date(n.startsAt).toLocaleString("ko-KR") : "제한 없음"}
                    {" ~ "}
                    {n.endsAt ? new Date(n.endsAt).toLocaleString("ko-KR") : "제한 없음"}
                  </td>
                  <td className={styles.linkCell} title={n.url ?? undefined}>
                    {n.url ?? "-"}
                  </td>
                  <td className={styles.actionsCell}>
                    <form action={`/api/admin/notices/${n.id}/delete`} method="post">
                      <button type="submit" className={styles.deleteButton}>
                        삭제
                      </button>
                    </form>
                  </td>
                </tr>
              ))}
              {notices.length === 0 && (
                <tr>
                  <td colSpan={5}>
                    <div className={styles.emptyState}>등록된 공지가 없습니다.</div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {addOpen && (
        <div className={styles.modalOverlay}>
          <Link href={buildListHref(false)} className={styles.modalBackdrop} aria-label="닫기" />
          <div className={`${styles.formCard} ${styles.modalCard}`}>
            <div className={styles.modalHeader}>
              <h2>공지 추가</h2>
              <Link href={buildListHref(false)} className={styles.modalCloseButton} aria-label="닫기">
                ✕
              </Link>
            </div>
            {error && (
              <p className={styles.bannerError}>
                {ERROR_MESSAGES[error] ?? `오류: ${error}`}
                {detail && ` (${detail})`}
              </p>
            )}
            <form action="/api/admin/notices" method="post">
              <label className={styles.field}>
                레벨
                <select name="level" required defaultValue="info">
                  {noticeLevelEnum.enumValues.map((l) => (
                    <option key={l} value={l}>
                      {LEVEL_LABEL[l] ?? l}
                    </option>
                  ))}
                </select>
              </label>
              <div className={styles.fieldRow}>
                <label className={styles.field}>
                  시작 일시 (선택, KST)
                  <input type="datetime-local" name="startsAt" />
                </label>
                <label className={styles.field}>
                  종료 일시 (선택, KST)
                  <input type="datetime-local" name="endsAt" />
                </label>
              </div>
              <label className={styles.field}>
                링크 (선택, https)
                <input type="url" name="url" placeholder="https://..." />
              </label>
              <label className={styles.field}>
                제목 (ko)
                <input type="text" name="titleKo" required />
              </label>
              <label className={styles.field}>
                본문 (ko)
                <textarea name="bodyKo" rows={3} required />
              </label>
              <label className={styles.field}>
                제목 (en)
                <input type="text" name="titleEn" required />
              </label>
              <label className={styles.field}>
                본문 (en)
                <textarea name="bodyEn" rows={3} required />
              </label>
              <button type="submit" className={styles.submitButton}>
                추가하고 게시
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
