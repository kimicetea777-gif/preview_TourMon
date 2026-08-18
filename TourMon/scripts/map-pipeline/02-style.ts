// 2단계: Protomaps 호스팅 스타일 생성 API(https://npm-style.protomaps.dev)에서
// style.json을 받아온 뒤, 벡터 소스 URL만 로컬 tileserver-gl 데이터 소스로 치환.
// @protomaps/basemaps를 로컬에 설치/빌드할 필요 없음 (Document/temp_2.md 참고).
import fs from "node:fs";
import path from "node:path";
import {
  PROTOMAPS_STYLE_API_URL,
  PROTOMAPS_STYLE_API_VERSION,
  PROTOMAPS_STYLE_LANG,
  PROTOMAPS_STYLE_THEME,
  STYLE_JSON,
  TILESERVER_DATA_SOURCE_NAME,
} from "./config.ts";

type StyleJson = {
  sources: Record<string, { type: string; url?: string }>;
  [key: string]: unknown;
};

async function main() {
  // tiles 파라미터는 스타일 생성에 쓰이지 않고 아래에서 로컬 소스로 덮어쓰므로 placeholder로 충분
  const url = new URL(PROTOMAPS_STYLE_API_URL);
  url.searchParams.set("version", PROTOMAPS_STYLE_API_VERSION);
  url.searchParams.set("theme", PROTOMAPS_STYLE_THEME);
  url.searchParams.set("lang", PROTOMAPS_STYLE_LANG);
  url.searchParams.set("tiles", "https://placeholder.invalid/tiles.json");

  console.log(`스타일 요청: ${url.toString()}`);
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`스타일 생성 API 실패: ${res.status} ${res.statusText}`);
  }
  const style = (await res.json()) as StyleJson;

  const sourceKeys = Object.keys(style.sources);
  if (sourceKeys.length !== 1) {
    throw new Error(
      `예상과 다른 sources 개수(${sourceKeys.length}) — API 응답 구조가 바뀌었을 수 있음, 수동 확인 필요`
    );
  }
  const [sourceKey] = sourceKeys;
  style.sources[sourceKey] = {
    type: "vector",
    url: `pmtiles://${TILESERVER_DATA_SOURCE_NAME}`,
  };

  fs.mkdirSync(path.dirname(STYLE_JSON), { recursive: true });
  fs.writeFileSync(STYLE_JSON, JSON.stringify(style, null, 2));
  console.log(`스타일 저장 완료: ${STYLE_JSON} (source key: ${sourceKey})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
