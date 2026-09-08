import Link from "next/link";
import type { LegalDocument as LegalDocumentData } from "@/content/legal/types";

function fillPlaceholders(text: string, contactEmail?: string): string {
  if (!contactEmail) return text;
  return text.replaceAll("{{CONTACT_EMAIL}}", contactEmail);
}

export default function LegalDocument({
  doc,
  contactEmail,
}: {
  doc: LegalDocumentData;
  contactEmail?: string;
}) {
  return (
    <>
      {/* 약관/개인정보/도움말/크레딧은 앱에서 외부 브라우저로 바로 열려 브라우저 히스토리가
          없을 수 있으므로, 상단에 고정된 브랜드 헤더가 곧 인덱스로 돌아가는 경로가 된다. */}
      <header className="legal-topbar">
        <Link href="/" className="legal-topbar-brand" aria-label="TourMon 홈으로">
          <img src="/logo.png" alt="" width={28} height={28} />
          <span>TourMon</span>
        </Link>
      </header>
      <main className="legal">
        <h1>{doc.title}</h1>
        <p className="legal-effective-date">{doc.effectiveDate}</p>
        {doc.sections.map((section, index) => (
          <section key={index}>
            {section.heading && <h2>{section.heading}</h2>}
            {section.paragraphs?.map((paragraph, pIndex) => (
              <p key={pIndex}>{fillPlaceholders(paragraph, contactEmail)}</p>
            ))}
            {section.list && (
              <ul>
                {section.list.map((item, lIndex) => (
                  <li key={lIndex}>{fillPlaceholders(item, contactEmail)}</li>
                ))}
              </ul>
            )}
          </section>
        ))}
      </main>
    </>
  );
}
