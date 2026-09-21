CREATE TYPE "public"."notice_level" AS ENUM('info', 'warn', 'critical');--> statement-breakpoint
CREATE TABLE "app_notice_translations" (
	"notice_id" integer NOT NULL,
	"locale" text NOT NULL,
	"title" text NOT NULL,
	"body" text NOT NULL,
	CONSTRAINT "app_notice_translations_notice_id_locale_pk" PRIMARY KEY("notice_id","locale")
);
--> statement-breakpoint
CREATE TABLE "app_notices" (
	"id" serial PRIMARY KEY NOT NULL,
	"level" "notice_level" NOT NULL,
	"starts_at" timestamp with time zone,
	"ends_at" timestamp with time zone,
	"url" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "app_notice_translations" ADD CONSTRAINT "app_notice_translations_notice_id_app_notices_id_fk" FOREIGN KEY ("notice_id") REFERENCES "public"."app_notices"("id") ON DELETE cascade ON UPDATE no action;