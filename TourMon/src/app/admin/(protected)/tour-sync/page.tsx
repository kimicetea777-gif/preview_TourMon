import { getTourSyncStatus } from "@/lib/admin/tour-sync-status";
import styles from "./tour-sync.module.css";

const ERROR_MESSAGES: Record<string, string> = {
  already_running: "이미 동기화가 실행 중입니다 — 끝난 뒤 다시 시도해 주세요.",
};

type SearchParams = Promise<{ started?: string; error?: string }>;

function formatDuration(startedAt: number, finishedAt: number): string {
  const seconds = Math.round((finishedAt - startedAt) / 1000);
  return seconds < 60 ? `${seconds}초` : `${Math.floor(seconds / 60)}분 ${seconds % 60}초`;
}

export default async function AdminTourSyncPage({ searchParams }: { searchParams: SearchParams }) {
  const { started, error } = await searchParams;
  const status = getTourSyncStatus();

  return (
    <div className={styles.page}>
      <div>
        <p className={styles.eyebrow}>PIPELINE</p>
        <h1 className={styles.title}>TourAPI 배치 동기화</h1>
        <p className={styles.subtitle}>
          관광지 데이터를 TourAPI에서 다시 받아오고(<code>tour:sync</code>), 좌표 중복 그룹을 재계산합니다(
          <code>tour:dedupe-spots</code>). 두 단계는 항상 이 순서로 같이 실행됩니다 — 수 분 정도 걸릴 수 있고
          완료 전에 페이지를 벗어나도 서버에서는 계속 진행됩니다.
        </p>
      </div>

      {started && <p className={styles.bannerSuccess}>동기화를 시작했습니다 — 아래 상태가 갱신되면 새로고침해 확인하세요.</p>}
      {error && <p className={styles.bannerError}>{ERROR_MESSAGES[error] ?? `오류: ${error}`}</p>}

      <section className={styles.statusCard}>
        <StatusView status={status} />
      </section>

      <div className={styles.actionRow}>
        <form action="/api/admin/tour-sync" method="post">
          <button type="submit" className={styles.runButton} disabled={status.phase === "running"}>
            {status.phase === "running" ? "실행 중..." : "지금 동기화 실행"}
          </button>
        </form>

        <p className={styles.footnote}>
          전체 로그가 필요하면 배포 서버에서 <code>docker compose logs -f app</code>로 확인할 수 있습니다
          (Document/build_manual.md 10번 참고).
        </p>
      </div>
    </div>
  );
}

function StatusView({ status }: { status: ReturnType<typeof getTourSyncStatus> }) {
  if (status.phase === "idle") {
    return (
      <div className={styles.statusHeader}>
        <span className={`${styles.badge} ${styles.badgeIdle}`}>
          <span className={styles.statusDot} />
          대기 중
        </span>
        <span className={styles.statusMeta}>아직 이 서버에서 실행된 적이 없습니다.</span>
      </div>
    );
  }

  if (status.phase === "running") {
    return (
      <div className={styles.statusHeader}>
        <span className={`${styles.badge} ${styles.badgeRunning}`}>
          <span className={`${styles.statusDot} ${styles.statusDotPulse}`} />
          실행 중
        </span>
        <span className={styles.statusMeta}>{new Date(status.startedAt).toLocaleString("ko-KR")}에 시작됨</span>
      </div>
    );
  }

  if (status.phase === "success") {
    return (
      <div className={styles.statusBody}>
        <div className={styles.statusHeader}>
          <span className={`${styles.badge} ${styles.badgeSuccess}`}>
            <span className={styles.statusDot} />
            성공
          </span>
          <span className={styles.statusMeta}>
            {new Date(status.finishedAt).toLocaleString("ko-KR")} · {formatDuration(status.startedAt, status.finishedAt)} 소요
          </span>
        </div>
        <p className={styles.statusSummary}>{status.summary}</p>
      </div>
    );
  }

  return (
    <div className={styles.statusBody}>
      <div className={styles.statusHeader}>
        <span className={`${styles.badge} ${styles.badgeError}`}>
          <span className={styles.statusDot} />
          실패
        </span>
        <span className={styles.statusMeta}>
          {new Date(status.finishedAt).toLocaleString("ko-KR")} · {formatDuration(status.startedAt, status.finishedAt)} 소요
        </span>
      </div>
      <p className={`${styles.statusSummary} ${styles.statusSummaryError}`}>{status.message}</p>
    </div>
  );
}
