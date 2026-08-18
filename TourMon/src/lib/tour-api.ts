// 한국관광공사 TourAPI 4.0 클라이언트 — 국문(KorService2)/영문(EngService2) 공용.
// Next.js 런타임(API 라우트)과 scripts/tour-sync 배치 스크립트 양쪽에서 재사용.
// 상세 엔드포인트/파라미터: Document/tour_api_detail.md 참고.

export type TourApiService = "kor" | "eng";

const MOBILE_APP_NAME = "TourMon";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`.env에 ${name}이 없음`);
  }
  return value;
}

function baseUrlFor(service: TourApiService): string {
  return requireEnv(
    service === "kor" ? "TOUR_API_KOR_BASE_URL" : "TOUR_API_ENG_BASE_URL",
  );
}

interface TourApiEnvelope<T> {
  // 정상 응답은 response.header/body로 감싸져 있지만, 게이트웨이 레벨 오류(예: 잘못된 파라미터)는
  // resultCode/resultMsg가 최상위에 바로 오는 flat 구조로 옴 — 둘 다 처리해야 함.
  response?: {
    header: { resultCode: string; resultMsg: string };
    body?: {
      items?: { item?: T | T[] } | "";
      numOfRows?: number;
      pageNo?: number;
      totalCount?: number;
    };
  };
  resultCode?: string;
  resultMsg?: string;
}

function normalizeItems<T>(items: { item?: T | T[] } | "" | undefined): T[] {
  if (!items || !items.item) return [];
  return Array.isArray(items.item) ? items.item : [items.item];
}

async function callTourApi<T>(
  service: TourApiService,
  operation: string,
  params: Record<string, string | number | undefined>,
): Promise<{ items: T[]; totalCount: number }> {
  const serviceKey = requireEnv("TOUR_API_SERVICE_KEY");

  const query = new URLSearchParams({
    MobileOS: "ETC",
    MobileApp: MOBILE_APP_NAME,
    _type: "json",
  });
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined) query.set(key, String(value));
  }

  // serviceKey는 URLSearchParams가 아니라 별도로 encodeURIComponent — data.go.kr 인증키의
  // '+', '/' 등 특수문자가 URLSearchParams 인코딩과 이중 인코딩 충돌을 일으키는 걸 방지 (.env 주석 참고)
  const url = `${baseUrlFor(service)}/${operation}?serviceKey=${encodeURIComponent(serviceKey)}&${query.toString()}`;

  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`TourAPI HTTP 오류 (${operation}, ${service}): ${res.status}`);
  }

  const json = (await res.json()) as TourApiEnvelope<T>;
  const { resultCode, resultMsg } = json.response?.header ?? {
    resultCode: json.resultCode!,
    resultMsg: json.resultMsg!,
  };
  if (resultCode !== "0000") {
    throw new Error(`TourAPI 오류 (${operation}, ${service}): [${resultCode}] ${resultMsg}`);
  }

  return {
    items: normalizeItems<T>(json.response?.body?.items),
    totalCount: json.response?.body?.totalCount ?? 0,
  };
}

// ── areaBasedSyncList2 ──────────────────────────────────────────────────────

export interface AreaBasedSyncItem {
  contentid: string;
  contenttypeid: string;
  title: string;
  addr1?: string;
  addr2?: string;
  tel?: string;
  firstimage?: string;
  cpyrhtDivCd?: string;
  mapx: string;
  mapy: string;
  lDongRegnCd?: string;
  lDongSignguCd?: string;
  modifiedtime: string;
  showflag?: string; // "1"=표출, "0"=비표출
}

export function fetchAreaBasedSyncList(params: {
  service: TourApiService;
  lDongRegnCd: string;
  lDongSignguCd?: string;
  modifiedtime?: string; // YYYYMMDD
  pageNo: number;
  numOfRows: number;
}) {
  const { service, ...rest } = params;
  return callTourApi<AreaBasedSyncItem>(service, "areaBasedSyncList2", {
    ...rest,
    arrange: "A",
  });
}

// ── ldongCode2 ───────────────────────────────────────────────────────────────

export interface LdongCodeItem {
  code: string;
  name: string;
}

export function fetchLdongCode(params: {
  service: TourApiService;
  lDongRegnCd?: string;
}) {
  const { service, lDongRegnCd } = params;
  return callTourApi<LdongCodeItem>(service, "ldongCode2", {
    lDongRegnCd,
    lDongListYn: "N",
    numOfRows: 100,
    pageNo: 1,
  });
}

// ── detailCommon2 ────────────────────────────────────────────────────────────

export interface DetailCommonItem {
  contentid: string;
  contenttypeid: string;
  title: string;
  overview?: string;
  homepage?: string;
  tel?: string;
}

export async function fetchDetailCommon(params: {
  service: TourApiService;
  contentId: string;
}) {
  const { items } = await callTourApi<DetailCommonItem>(
    params.service,
    "detailCommon2",
    { contentId: params.contentId },
  );
  return items[0];
}

// ── detailImage2 ─────────────────────────────────────────────────────────────

export interface DetailImageItem {
  contentid: string;
  originimgurl: string;
  imgname?: string;
  smallimageurl?: string;
  cpyrhtDivCd?: string;
  serialnum?: string;
}

export function fetchDetailImage(params: {
  service: TourApiService;
  contentId: string;
}) {
  return callTourApi<DetailImageItem>(params.service, "detailImage2", {
    contentId: params.contentId,
    imageYN: "Y",
  });
}
