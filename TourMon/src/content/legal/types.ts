export type LegalLocale = "ko" | "en";

export type LegalSection = {
  heading: string;
  paragraphs?: string[];
  list?: string[];
};

export type LegalDocument = {
  title: string;
  effectiveDate: string;
  sections: LegalSection[];
};
