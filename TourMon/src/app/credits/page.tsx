import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";
import { creditsContent } from "@/content/credits/attribution";
import { resolveLegalLocale } from "@/lib/legal-locale";

type SearchParams = Promise<{ locale?: string | string[] }>;

export async function generateMetadata({
  searchParams,
}: {
  searchParams: SearchParams;
}): Promise<Metadata> {
  const locale = await resolveLegalLocale(await searchParams);
  return { title: creditsContent[locale].title };
}

export default async function CreditsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const locale = await resolveLegalLocale(await searchParams);
  return (
    <LegalDocument
      doc={creditsContent[locale]}
      contactEmail={process.env.CONTACT_EMAIL}
    />
  );
}
