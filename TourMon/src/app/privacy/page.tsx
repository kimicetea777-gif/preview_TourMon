import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";
import { privacyContent } from "@/content/legal/privacy";
import { resolveLegalLocale } from "@/lib/legal-locale";

type SearchParams = Promise<{ locale?: string | string[] }>;

export async function generateMetadata({
  searchParams,
}: {
  searchParams: SearchParams;
}): Promise<Metadata> {
  const locale = await resolveLegalLocale(await searchParams);
  return { title: privacyContent[locale].title };
}

export default async function PrivacyPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const locale = await resolveLegalLocale(await searchParams);
  return (
    <LegalDocument
      doc={privacyContent[locale]}
      contactEmail={process.env.CONTACT_EMAIL}
    />
  );
}
