import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";
import { termsContent } from "@/content/legal/terms";
import { resolveLegalLocale } from "@/lib/legal-locale";

type SearchParams = Promise<{ locale?: string | string[] }>;

export async function generateMetadata({
  searchParams,
}: {
  searchParams: SearchParams;
}): Promise<Metadata> {
  const locale = await resolveLegalLocale(await searchParams);
  return { title: termsContent[locale].title };
}

export default async function TermsPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const locale = await resolveLegalLocale(await searchParams);
  return (
    <LegalDocument
      doc={termsContent[locale]}
      contactEmail={process.env.CONTACT_EMAIL}
    />
  );
}
