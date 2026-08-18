CREATE TYPE "public"."eng_match_review_status" AS ENUM('pending', 'resolved', 'rejected');--> statement-breakpoint
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
ALTER TABLE "eng_match_reviews" ADD CONSTRAINT "eng_match_reviews_content_type_id_content_types_id_fk" FOREIGN KEY ("content_type_id") REFERENCES "public"."content_types"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "eng_match_reviews" ADD CONSTRAINT "eng_match_reviews_resolved_tourism_spot_id_tourism_spots_id_fk" FOREIGN KEY ("resolved_tourism_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;