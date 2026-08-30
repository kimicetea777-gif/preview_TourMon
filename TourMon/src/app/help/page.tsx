import type { Metadata } from "next";
import LegalDocument from "@/components/LegalDocument";
import { helpContent } from "@/content/help/troubleshooting";
import { resolveLegalLocale } from "@/lib/legal-locale";

type SearchParams = Promise<{ locale?: string | string[] }>;

export async function generateMetadata({
  searchParams,
}: {
  searchParams: SearchParams;
}): Promise<Metadata> {
  const locale = await resolveLegalLocale(await searchParams);
  return { title: helpContent[locale].title };
}

export default async function HelpPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const locale = await resolveLegalLocale(await searchParams);
  return (
    <LegalDocument
      doc={helpContent[locale]}
      contactEmail={process.env.CONTACT_EMAIL}
    />
  );
}
