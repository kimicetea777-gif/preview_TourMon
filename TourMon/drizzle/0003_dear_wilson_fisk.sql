CREATE TABLE "egg_vouchers" (
	"id" uuid PRIMARY KEY NOT NULL,
	"egg_type_id" integer NOT NULL,
	"rarity" "rarity_tier" NOT NULL,
	"target_steps" integer NOT NULL,
	"issued_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "egg_vouchers" ADD CONSTRAINT "egg_vouchers_egg_type_id_egg_types_id_fk" FOREIGN KEY ("egg_type_id") REFERENCES "public"."egg_types"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "egg_vouchers_issued_at_idx" ON "egg_vouchers" USING btree ("issued_at");