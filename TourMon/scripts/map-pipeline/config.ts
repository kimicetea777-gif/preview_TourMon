// 1단계 배경 지도 파이프라인 설정값 — 하드코딩 금지 원칙에 따라 모든 튜닝 값을 이 파일 한 곳에 모음.
// 상세 결정 배경: Document/temp_2.md

import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const PIPELINE_DIR = __dirname;
export const DATA_DIR = path.join(__dirname, "data");
export const BIN_DIR = path.join(__dirname, "bin");
export const TILESERVER_DIR = path.join(__dirname, "tileserver");

// pmtiles.exe (go-pmtiles) 바이너리 경로 — 01-extract.ts 참고
export const PMTILES_BIN = path.join(BIN_DIR, "pmtiles.exe");

// 서울+인천 bounding box: 도심+강화도 포함, 백령도 등 원거리 도서 제외
// (TourAPI 관광지 밀도가 사실상 없는 지역이라 PMTiles 추출 범위에서 뺌)
export const BBOX = {
  minLon: 126.35,
  minLat: 37.2,
  maxLon: 127.2,
  maxLat: 37.75,
} as const;

export const BBOX_STRING = `${BBOX.minLon},${BBOX.minLat},${BBOX.maxLon},${BBOX.maxLat}`;

// 래스터 렌더링 줌 레벨 범위. z17+ 는 이번 단계에서 렌더링하지 않고
// Flutter 쪽 TileLayer의 maxNativeZoom으로 오버줌(업스케일) 처리 (Document/temp_2.md 참고)
export const MIN_ZOOM = 0;
export const MAX_ZOOM = 16;

// Protomaps 공개 벡터 PMTiles 빌드 메타데이터 — 날짜를 하드코딩하지 않고 실행 시점에 최신 빌드를 조회
export const PROTOMAPS_BUILDS_METADATA_URL = "https://build-metadata.protomaps.dev/builds.json";
export const PROTOMAPS_BUILD_BASE_URL = "https://build.protomaps.com";

// Protomaps 호스팅 스타일 생성 API — @protomaps/basemaps를 로컬에 설치할 필요 없이
// style.json을 받아온 뒤 소스 URL만 로컬 tileserver-gl 데이터 소스로 치환해서 사용
export const PROTOMAPS_STYLE_API_URL = "https://npm-style.protomaps.dev/style.json";
// @protomaps/basemaps(npm) 버전 — 이 값에 맞는 스타일 스펙을 생성해줌. 새 스타일 기능이 필요해지면
// `npm view @protomaps/basemaps version`으로 최신값 확인 후 갱신
export const PROTOMAPS_STYLE_API_VERSION = "5.7.2";
export const PROTOMAPS_STYLE_THEME = "light";
export const PROTOMAPS_STYLE_LANG = "en";

// 로컬 산출물 파일명
export const EXTRACTED_VECTOR_PMTILES = path.join(DATA_DIR, "seoul-incheon.pmtiles");
export const STYLE_JSON = path.join(TILESERVER_DIR, "styles", "light.json");
export const TILESERVER_CONFIG_JSON = path.join(TILESERVER_DIR, "config.json");
export const RENDERED_TILES_DIR = path.join(DATA_DIR, "tiles");
export const RASTER_MBTILES = path.join(DATA_DIR, "seoul-incheon-raster.mbtiles");
export const RASTER_PMTILES = path.join(DATA_DIR, "seoul-incheon-raster.pmtiles");

// tileserver-gl (Docker) 로컬 렌더링용 설정
export const TILESERVER_PORT = 8090;
export const TILESERVER_DATA_SOURCE_NAME = "seoul_incheon_vector";
export const TILESERVER_STYLE_NAME = "light";

// R2 업로드 대상 키 (버킷은 .env의 R2_BUCKET_NAME 재사용)
export const R2_OBJECT_KEY = "maps/seoul-incheon-raster.pmtiles";

// 렌더 타일 배치 요청 동시성 (03-render.ts)
export const RENDER_CONCURRENCY = 12;

// 로컬 개발용 PMTiles 서빙 포트 (docker-compose pmtiles-server 서비스)
export const PMTILES_SERVE_PORT = 8080;
export const PMTILES_SERVE_ARCHIVE_NAME = "seoul-incheon-raster";
