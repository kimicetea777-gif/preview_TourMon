import { sql } from "drizzle-orm";
import {
  boolean,
  check,
  customType,
  index,
  integer,
  numeric,
  pgEnum,
  pgTable,
  primaryKey,
  serial,
  text,
  timestamp,
  unique,
  uuid,
  type AnyPgColumn,
} from "drizzle-orm/pg-core";

// ── ENUM ──────────────────────────────────────────────────────────────────

export const rarityTierEnum = pgEnum("rarity_tier", [
  "common",
  "rare",
  "epic",
  "legendary",
]);

// TODO: 실제 속성 목록 게임 디자인에서 확정 필요 (init_plan.md 6번 섹션 참고). 값 목록만 TBD, 아래는 placeholder.
export const monsterAttributeEnum = pgEnum("monster_attribute", [
  "grass",
  "water",
  "fire",
  "psychic",
  "ghost",
]);

// PostGIS geography(Point,4326). 값은 WKT 문자열("POINT(lng lat)")로 주고받는다.
// ⚠️ drizzle-kit generate가 이 dataType() 반환값을 통째로 식별자로 착각해 따옴표로 감싸서
// `"geography(Point,4326)"`(존재하지 않는 타입) SQL을 만드는 버그가 있음 — 이 컬럼을 건드리는
// 마이그레이션을 새로 generate할 때마다 생성된 .sql에서 따옴표를 수동으로 제거해야 함.
const geographyPoint = customType<{ data: string }>({
  dataType() {
    return "geography(Point,4326)";
  },
});

// ── 참조 테이블 ────────────────────────────────────────────────────────────

export const users = pgTable("users", {
  id: uuid("id").primaryKey(), // AS의 sub 값 그대로 (FK 아님, AS는 외부 시스템)
  nickname: text("nickname").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  lastSyncedAt: timestamp("last_synced_at", { withTimezone: true }),
});

export const regions = pgTable("regions", {
  code: text("code").primaryKey(), // TourAPI lDongRegnCd
  name: text("name").notNull(),
  isEnabled: boolean("is_enabled").notNull().default(true),
});

export const contentTypes = pgTable("content_types", {
  id: integer("id").primaryKey(), // TourAPI 국문코드 (12/14/15/25/28/32/38/39)
  name: text("name").notNull(),
  foreignCode: integer("foreign_code"), // TourAPI 다국어코드, 없을 수 있음(예: 여행코스)
  // 숙박/음식점/쇼핑처럼 "관광지"로 보기 애매한 유형은 지도엔 표시하되 알 획득은 막기 위한 플래그
  // (2026-08-18 결정, Document/plan/later.md 좌표 중복 실측에서 쇼핑 비중이 과도하게 높다는 게 계기).
  // 하드코딩 대신 DB 컬럼으로 둬서 나중에 유형 추가/조정 시 코드 변경 없이 값만 바꾸면 됨.
  eggAcquisitionEnabled: boolean("egg_acquisition_enabled").notNull().default(true),
});

export const tourismSpots = pgTable("tourism_spots", {
  id: serial("id").primaryKey(),
  contentId: text("content_id").notNull().unique(), // TourAPI contentid
  title: text("title").notNull(),
  titleEn: text("title_en"),
  addr1: text("addr1"),
  addr2: text("addr2"),
  tel: text("tel"),
  addr1En: text("addr1_en"),
  addr2En: text("addr2_en"),
  // 영문(EngService2) 서비스의 contentid — 국문/영문 서비스는 ID 체계가 서로 달라
  // detailCommon2/detailImage2를 영문으로 부르려면 이 값이 별도로 필요함. scripts/tour-sync/
  // eng-match.ts가 좌표 매칭으로 채움, 매칭 실패 시 null(국문 서비스로 폴백).
  contentIdEn: text("content_id_en"),
  locationGeog: geographyPoint("location_geog").notNull(),
  contentTypeId: integer("content_type_id")
    .notNull()
    .references(() => contentTypes.id, { onDelete: "restrict" }),
  firstImage: text("first_image"),
  cpyrhtDivCd: text("cpyrht_div_cd"), // 공공누리 저작권 구분코드 (Type1/Type3 등)
  isActive: boolean("is_active").notNull().default(true), // TourAPI showflag=0(비표출) 감지 시 false — 하드 삭제 대신 비활성화
  regionCode: text("region_code")
    .notNull()
    .references(() => regions.code, { onDelete: "restrict" }),
  // 좌표 중복(같은 건물 내 여러 매장) 그룹핑 — dedup 배치(scripts/tour-sync)가 동기화 시점에
  // 미리 계산해서 써넣음, 요청 시점 계산 아님(Document/temp.md "관광지 마커 — 좌표 중복" 결정 배경 참고).
  // 클러스터 멤버 전원(대표 자신 포함, 자기 id를 가리킴)에 대표의 id를 채움. 혼자인 spot도 자기 id로 채움.
  representativeSpotId: integer("representative_spot_id").references(
    (): AnyPgColumn => tourismSpots.id,
    { onDelete: "set null" },
  ),
  // dedup 배치가 대표를 고를 때 우선 적용하는 수동 오버라이드(기본값 content_id 최소값보다 우선).
  // 값을 바꿔도 dedup 배치 재실행 전까지는 반영 안 됨(실시간 재계산 아님).
  representativePriority: integer("representative_priority"),
  // representativeSpotId = id 와 동일한 정보의 비정규화 컬럼 — 마커 조회 핫패스(팬/줌마다 호출)에서
  // 두 컬럼을 비교하는 대신 이 값 하나로 바로 인덱스 필터링하기 위함.
  isRepresentative: boolean("is_representative").notNull().default(true),
  // 대표 spot 기준 클러스터 멤버 수(자기 자신 포함, 1이면 중복 없는 solo) — dedup 배치가 채움.
  // 클라이언트가 "묶인 관광지 보기" 버튼을 보여줄지 별도 API 호출 없이 마커 데이터만으로 판단하기 위함.
  memberCount: integer("member_count").notNull().default(1),
  createdAt: timestamp("created_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  syncedAt: timestamp("synced_at", { withTimezone: true }).notNull(),
}, (table) => [
  index("tourism_spots_location_geog_gist").using("gist", table.locationGeog),
  index("tourism_spots_representative_spot_id_idx").on(table.representativeSpotId),
  index("tourism_spots_is_representative_idx").on(table.isRepresentative),
]);

// 7단계 — 국문/영문 좌표 매칭 시(scripts/tour-sync/eng-match.ts) 반경 안에 content_type이 호환되는
// 국문 후보가 2개 이상 걸려서(같은 건물 안 여러 매장 등) 자동으로 하나를 못 고른 영문 항목을
// 보관. 아직 관리자 페이지는 없음 — 지금은 이 테이블에 쌓아두기만 하고, 나중에 관리자 페이지가
// 생기면 candidateTourismSpotIds 중 하나를 골라 resolvedTourismSpotId에 채우는 방식으로 처리할
// 예정(그 UPDATE 로직 자체는 7단계 스코프 밖, 이번엔 데이터 적재만).
export const engMatchReviewStatusEnum = pgEnum("eng_match_review_status", [
  "pending",
  "resolved",
  "rejected",
]);

export const engMatchReviews = pgTable("eng_match_reviews", {
  id: serial("id").primaryKey(),
  contentIdEn: text("content_id_en").notNull().unique(), // 재실행 시 중복 적재 방지 키
  titleEn: text("title_en").notNull(),
  addr1En: text("addr1_en"),
  addr2En: text("addr2_en"),
  locationGeog: geographyPoint("location_geog").notNull(),
  contentTypeId: integer("content_type_id").references(() => contentTypes.id, {
    onDelete: "set null",
  }),
  candidateTourismSpotIds: integer("candidate_tourism_spot_ids").array().notNull(),
  status: engMatchReviewStatusEnum("status").notNull().default("pending"),
  resolvedTourismSpotId: integer("resolved_tourism_spot_id").references(
    () => tourismSpots.id,
    { onDelete: "set null" },
  ),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  resolvedAt: timestamp("resolved_at", { withTimezone: true }),
});

// ── 알/몬스터 마스터 데이터 ─────────────────────────────────────────────────

export const eggTypes = pgTable("egg_types", {
  id: serial("id").primaryKey(),
  rarity: rarityTierEnum("rarity").notNull(),
  targetSteps: integer("target_steps").notNull(),
  isActive: boolean("is_active").notNull().default(true),
  weight: numeric("weight").notNull().default("1"),
}, (table) => [
  check("egg_types_target_steps_positive", sql`${table.targetSteps} > 0`),
  check("egg_types_weight_non_negative", sql`${table.weight} >= 0`),
]);

export const eggTypeTranslations = pgTable("egg_type_translations", {
  eggTypeId: integer("egg_type_id")
    .notNull()
    .references(() => eggTypes.id, { onDelete: "cascade" }),
  locale: text("locale").notNull(), // 'ko' | 'en'
  name: text("name").notNull(),
  description: text("description"),
}, (table) => [
  primaryKey({ columns: [table.eggTypeId, table.locale] }),
]);

export const monsterSpecies = pgTable("monster_species", {
  id: serial("id").primaryKey(),
  attribute: monsterAttributeEnum("attribute").notNull(),
  dexNumber: integer("dex_number").notNull().unique(),
  imageUrl: text("image_url").notNull(),
  animationUrl: text("animation_url"),
  rarity: rarityTierEnum("rarity").notNull(),
  evolvesFromId: integer("evolves_from_id").references(
    (): AnyPgColumn => monsterSpecies.id,
    { onDelete: "set null" },
  ),
  evolvesToId: integer("evolves_to_id").references(
    (): AnyPgColumn => monsterSpecies.id,
    { onDelete: "set null" },
  ),
  evolutionStage: integer("evolution_stage"),
}, (table) => [
  check("monster_species_dex_number_positive", sql`${table.dexNumber} > 0`),
  check(
    "monster_species_evolution_stage_positive",
    sql`${table.evolutionStage} > 0`,
  ),
]);

export const monsterSpeciesTranslations = pgTable(
  "monster_species_translations",
  {
    monsterSpeciesId: integer("monster_species_id")
      .notNull()
      .references(() => monsterSpecies.id, { onDelete: "cascade" }),
    locale: text("locale").notNull(), // 'ko' | 'en'
    name: text("name").notNull(),
    description: text("description"),
  },
  (table) => [primaryKey({ columns: [table.monsterSpeciesId, table.locale] })],
);

export const monsterAttributeWeights = pgTable("monster_attribute_weights", {
  id: serial("id").primaryKey(),
  contentTypeId: integer("content_type_id")
    .notNull()
    .references(() => contentTypes.id, { onDelete: "restrict" }),
  monsterSpeciesId: integer("monster_species_id")
    .notNull()
    .references(() => monsterSpecies.id, { onDelete: "restrict" }),
  weight: numeric("weight").notNull().default("1"),
}, (table) => [
  unique("monster_attribute_weights_content_type_monster_unique").on(
    table.contentTypeId,
    table.monsterSpeciesId,
  ),
  check("monster_attribute_weights_weight_non_negative", sql`${table.weight} >= 0`),
]);

export const rarityWeightMultipliers = pgTable("rarity_weight_multipliers", {
  eggRarity: rarityTierEnum("egg_rarity").notNull(),
  monsterRarity: rarityTierEnum("monster_rarity").notNull(),
  multiplier: numeric("multiplier").notNull().default("1"),
}, (table) => [
  primaryKey({ columns: [table.eggRarity, table.monsterRarity] }),
  check(
    "rarity_weight_multipliers_multiplier_non_negative",
    sql`${table.multiplier} >= 0`,
  ),
]);

// ── 사용자 데이터 ──────────────────────────────────────────────────────────

// 게스트 로컬 알 데이터 위조 방지용 "발급 확인증" — user_id 컬럼이 없는 무기명 증서 구조로, 로그인
// 여부와 무관하게 /api/eggs/acquire가 egg_type을 배정할 때마다 생성된다. 마이그레이션/부화 시점에
// 클라이언트가 들고 온 알의 id+rarity+targetSteps가 이 값과 정확히 일치해야 통과, 통과 시 삭제(1회성).
// (init_plan.md 397~407줄, Document/study_folder/6-4_게스트 회원가입 마이그레이션.md)
export const eggVouchers = pgTable("egg_vouchers", {
  id: uuid("id").primaryKey(),
  eggTypeId: integer("egg_type_id")
    .notNull()
    .references(() => eggTypes.id, { onDelete: "restrict" }),
  rarity: rarityTierEnum("rarity").notNull(), // 발급 시점 스냅샷
  targetSteps: integer("target_steps").notNull(), // 발급 시점 스냅샷
  issuedAt: timestamp("issued_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
}, (table) => [
  // TTL 정리 배치(issued_at < now() - 90일)가 이 컬럼으로 범위 삭제하므로 인덱스 필요
  // (user_eggs_user_spot_acquired_idx와 같은 이유).
  index("egg_vouchers_issued_at_idx").on(table.issuedAt),
]);

export const userEggs = pgTable("user_eggs", {
  id: uuid("id").primaryKey(), // 클라이언트(게스트 로컬 or 서버) 생성 UUIDv7
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  eggTypeId: integer("egg_type_id")
    .notNull()
    .references(() => eggTypes.id, { onDelete: "restrict" }),
  tourismSpotId: integer("tourism_spot_id").references(
    () => tourismSpots.id,
    { onDelete: "set null" },
  ),
  targetSteps: integer("target_steps").notNull(), // 획득 시점 egg_types.target_steps 복사
  stepsAccumulated: integer("steps_accumulated").notNull().default(0),
  isPartner: boolean("is_partner").notNull().default(false),
  acquiredAt: timestamp("acquired_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
  hatchedAt: timestamp("hatched_at", { withTimezone: true }),
}, (table) => [
  index("user_eggs_user_spot_acquired_idx").on(
    table.userId,
    table.tourismSpotId,
    table.acquiredAt,
  ),
  check("user_eggs_target_steps_positive", sql`${table.targetSteps} > 0`),
  check(
    "user_eggs_steps_accumulated_non_negative",
    sql`${table.stepsAccumulated} >= 0`,
  ),
]);

export const stepSyncLogs = pgTable("step_sync_logs", {
  id: serial("id").primaryKey(),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  deltaSteps: integer("delta_steps").notNull(),
  syncedAt: timestamp("synced_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
}, (table) => [
  check("step_sync_logs_delta_steps_non_negative", sql`${table.deltaSteps} >= 0`),
]);

export const userMonsters = pgTable("user_monsters", {
  id: uuid("id").primaryKey(), // 클라이언트 생성 UUIDv7 (user_eggs와 동일한 이유)
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  monsterSpeciesId: integer("monster_species_id")
    .notNull()
    .references(() => monsterSpecies.id, { onDelete: "restrict" }),
  eggId: uuid("egg_id").references(() => userEggs.id, {
    onDelete: "set null",
  }),
  tourismSpotId: integer("tourism_spot_id").references(
    () => tourismSpots.id,
    { onDelete: "set null" },
  ),
  hatchedAt: timestamp("hatched_at", { withTimezone: true })
    .notNull()
    .defaultNow(),
});
