CREATE TYPE "public"."eng_match_review_status" AS ENUM('pending', 'resolved', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."monster_attribute" AS ENUM('grass', 'water', 'fire', 'psychic', 'ghost');--> statement-breakpoint
CREATE TYPE "public"."rarity_tier" AS ENUM('common', 'rare', 'epic', 'legendary');--> statement-breakpoint
CREATE TABLE "content_types" (
	"id" integer PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"foreign_code" integer,
	"egg_acquisition_enabled" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "egg_type_translations" (
	"egg_type_id" integer NOT NULL,
	"locale" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	CONSTRAINT "egg_type_translations_egg_type_id_locale_pk" PRIMARY KEY("egg_type_id","locale")
);
--> statement-breakpoint
CREATE TABLE "egg_types" (
	"id" serial PRIMARY KEY NOT NULL,
	"rarity" "rarity_tier" NOT NULL,
	"target_distance_meters" integer NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"weight" numeric DEFAULT '1' NOT NULL,
	CONSTRAINT "egg_types_target_distance_positive" CHECK ("egg_types"."target_distance_meters" > 0),
	CONSTRAINT "egg_types_weight_non_negative" CHECK ("egg_types"."weight" >= 0)
);
--> statement-breakpoint
CREATE TABLE "egg_vouchers" (
	"id" uuid PRIMARY KEY NOT NULL,
	"egg_type_id" integer NOT NULL,
	"rarity" "rarity_tier" NOT NULL,
	"target_distance_meters" integer NOT NULL,
	"issued_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "eng_match_reviews" (
	"id" serial PRIMARY KEY NOT NULL,
	"content_id_en" text NOT NULL,
	"title_en" text NOT NULL,
	"addr1_en" text,
	"addr2_en" text,
	"location_geog" geography(Point,4326) NOT NULL,
	"content_type_id" integer,
	"candidate_tourism_spot_ids" integer[] NOT NULL,
	"status" "eng_match_review_status" DEFAULT 'pending' NOT NULL,
	"resolved_tourism_spot_id" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"resolved_at" timestamp with time zone,
	CONSTRAINT "eng_match_reviews_content_id_en_unique" UNIQUE("content_id_en")
);
--> statement-breakpoint
CREATE TABLE "monster_attribute_weights" (
	"id" serial PRIMARY KEY NOT NULL,
	"content_type_id" integer NOT NULL,
	"monster_species_id" integer NOT NULL,
	"weight" numeric DEFAULT '1' NOT NULL,
	CONSTRAINT "monster_attribute_weights_content_type_monster_unique" UNIQUE("content_type_id","monster_species_id"),
	CONSTRAINT "monster_attribute_weights_weight_non_negative" CHECK ("monster_attribute_weights"."weight" >= 0)
);
--> statement-breakpoint
CREATE TABLE "monster_species" (
	"id" serial PRIMARY KEY NOT NULL,
	"attribute" "monster_attribute" NOT NULL,
	"dex_number" integer NOT NULL,
	"image_url" text NOT NULL,
	"animation_url" text,
	"rarity" "rarity_tier" NOT NULL,
	"evolves_from_id" integer,
	"evolves_to_id" integer,
	"evolution_stage" integer,
	CONSTRAINT "monster_species_dex_number_unique" UNIQUE("dex_number"),
	CONSTRAINT "monster_species_dex_number_positive" CHECK ("monster_species"."dex_number" > 0),
	CONSTRAINT "monster_species_evolution_stage_positive" CHECK ("monster_species"."evolution_stage" > 0)
);
--> statement-breakpoint
CREATE TABLE "monster_species_translations" (
	"monster_species_id" integer NOT NULL,
	"locale" text NOT NULL,
	"name" text NOT NULL,
	"description" text,
	CONSTRAINT "monster_species_translations_monster_species_id_locale_pk" PRIMARY KEY("monster_species_id","locale")
);
--> statement-breakpoint
CREATE TABLE "polling_cursors" (
	"poller_name" text PRIMARY KEY NOT NULL,
	"since_timestamp" timestamp with time zone NOT NULL,
	"since_id" bigint,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "rarity_weight_multipliers" (
	"egg_rarity" "rarity_tier" NOT NULL,
	"monster_rarity" "rarity_tier" NOT NULL,
	"multiplier" numeric DEFAULT '1' NOT NULL,
	CONSTRAINT "rarity_weight_multipliers_egg_rarity_monster_rarity_pk" PRIMARY KEY("egg_rarity","monster_rarity"),
	CONSTRAINT "rarity_weight_multipliers_multiplier_non_negative" CHECK ("rarity_weight_multipliers"."multiplier" >= 0)
);
--> statement-breakpoint
CREATE TABLE "regions" (
	"code" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"is_enabled" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tourism_spots" (
	"id" serial PRIMARY KEY NOT NULL,
	"content_id" text NOT NULL,
	"title" text NOT NULL,
	"title_en" text,
	"addr1" text,
	"addr2" text,
	"tel" text,
	"addr1_en" text,
	"addr2_en" text,
	"content_id_en" text,
	"location_geog" geography(Point,4326) NOT NULL,
	"content_type_id" integer NOT NULL,
	"first_image" text,
	"cpyrht_div_cd" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"region_code" text NOT NULL,
	"representative_spot_id" integer,
	"representative_priority" integer,
	"is_representative" boolean DEFAULT true NOT NULL,
	"member_count" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"synced_at" timestamp with time zone NOT NULL,
	CONSTRAINT "tourism_spots_content_id_unique" UNIQUE("content_id")
);
--> statement-breakpoint
CREATE TABLE "user_eggs" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"egg_type_id" integer NOT NULL,
	"tourism_spot_id" integer,
	"target_distance_meters" integer NOT NULL,
	"distance_accumulated_meters" integer DEFAULT 0 NOT NULL,
	"acquired_at" timestamp with time zone DEFAULT now() NOT NULL,
	"hatched_at" timestamp with time zone,
	CONSTRAINT "user_eggs_target_distance_positive" CHECK ("user_eggs"."target_distance_meters" > 0),
	CONSTRAINT "user_eggs_distance_accumulated_non_negative" CHECK ("user_eggs"."distance_accumulated_meters" >= 0)
);
--> statement-breakpoint
CREATE TABLE "user_monsters" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"monster_species_id" integer NOT NULL,
	"egg_id" uuid,
	"tourism_spot_id" integer,
	"hatched_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_monsters_egg_id_unique" UNIQUE("egg_id")
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"nickname" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_synced_at" timestamp with time zone,
	"membership_withdrawn_at" timestamp with time zone,
	"anonymized_at" timestamp with time zone,
	"last_distance_sync_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "egg_type_translations" ADD CONSTRAINT "egg_type_translations_egg_type_id_egg_types_id_fk" FOREIGN KEY ("egg_type_id") REFERENCES "public"."egg_types"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "egg_vouchers" ADD CONSTRAINT "egg_vouchers_egg_type_id_egg_types_id_fk" FOREIGN KEY ("egg_type_id") REFERENCES "public"."egg_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "eng_match_reviews" ADD CONSTRAINT "eng_match_reviews_content_type_id_content_types_id_fk" FOREIGN KEY ("content_type_id") REFERENCES "public"."content_types"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "eng_match_reviews" ADD CONSTRAINT "eng_match_reviews_resolved_tourism_spot_id_tourism_spots_id_fk" FOREIGN KEY ("resolved_tourism_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "monster_attribute_weights" ADD CONSTRAINT "monster_attribute_weights_content_type_id_content_types_id_fk" FOREIGN KEY ("content_type_id") REFERENCES "public"."content_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "monster_attribute_weights" ADD CONSTRAINT "monster_attribute_weights_monster_species_id_monster_species_id_fk" FOREIGN KEY ("monster_species_id") REFERENCES "public"."monster_species"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "monster_species" ADD CONSTRAINT "monster_species_evolves_from_id_monster_species_id_fk" FOREIGN KEY ("evolves_from_id") REFERENCES "public"."monster_species"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "monster_species" ADD CONSTRAINT "monster_species_evolves_to_id_monster_species_id_fk" FOREIGN KEY ("evolves_to_id") REFERENCES "public"."monster_species"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "monster_species_translations" ADD CONSTRAINT "monster_species_translations_monster_species_id_monster_species_id_fk" FOREIGN KEY ("monster_species_id") REFERENCES "public"."monster_species"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD CONSTRAINT "tourism_spots_content_type_id_content_types_id_fk" FOREIGN KEY ("content_type_id") REFERENCES "public"."content_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD CONSTRAINT "tourism_spots_region_code_regions_code_fk" FOREIGN KEY ("region_code") REFERENCES "public"."regions"("code") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD CONSTRAINT "tourism_spots_representative_spot_id_tourism_spots_id_fk" FOREIGN KEY ("representative_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_eggs" ADD CONSTRAINT "user_eggs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_eggs" ADD CONSTRAINT "user_eggs_egg_type_id_egg_types_id_fk" FOREIGN KEY ("egg_type_id") REFERENCES "public"."egg_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_eggs" ADD CONSTRAINT "user_eggs_tourism_spot_id_tourism_spots_id_fk" FOREIGN KEY ("tourism_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_monsters" ADD CONSTRAINT "user_monsters_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_monsters" ADD CONSTRAINT "user_monsters_monster_species_id_monster_species_id_fk" FOREIGN KEY ("monster_species_id") REFERENCES "public"."monster_species"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_monsters" ADD CONSTRAINT "user_monsters_egg_id_user_eggs_id_fk" FOREIGN KEY ("egg_id") REFERENCES "public"."user_eggs"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_monsters" ADD CONSTRAINT "user_monsters_tourism_spot_id_tourism_spots_id_fk" FOREIGN KEY ("tourism_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "egg_vouchers_issued_at_idx" ON "egg_vouchers" USING btree ("issued_at");--> statement-breakpoint
CREATE INDEX "tourism_spots_location_geog_gist" ON "tourism_spots" USING gist ("location_geog");--> statement-breakpoint
CREATE INDEX "tourism_spots_representative_spot_id_idx" ON "tourism_spots" USING btree ("representative_spot_id");--> statement-breakpoint
CREATE INDEX "tourism_spots_is_representative_idx" ON "tourism_spots" USING btree ("is_representative");--> statement-breakpoint
CREATE INDEX "user_eggs_user_spot_acquired_idx" ON "user_eggs" USING btree ("user_id","tourism_spot_id","acquired_at");