ALTER TABLE "tourism_spots" ADD COLUMN "representative_spot_id" integer;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD COLUMN "representative_priority" integer;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD COLUMN "is_representative" boolean DEFAULT true NOT NULL;--> statement-breakpoint
ALTER TABLE "tourism_spots" ADD CONSTRAINT "tourism_spots_representative_spot_id_tourism_spots_id_fk" FOREIGN KEY ("representative_spot_id") REFERENCES "public"."tourism_spots"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "tourism_spots_representative_spot_id_idx" ON "tourism_spots" USING btree ("representative_spot_id");--> statement-breakpoint
CREATE INDEX "tourism_spots_is_representative_idx" ON "tourism_spots" USING btree ("is_representative");