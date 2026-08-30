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
  );
}
