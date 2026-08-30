import type { LegalDocument, LegalLocale } from "../legal/types";

// 앱에 표시되는 관광 정보/사진은 전부 한국관광공사 TourAPI 응답이고, 이 데이터는 공공데이터포털에서
// 공공누리 제1유형(출처표시) 조건으로 개방된 것이라 출처표시 의무가 있음. 앱 안(상세 시트 하단
// 캡션, 이미지 뷰어 하단)에는 짧은 한 줄만 넣고, 정식 문구와 지도(OpenStreetMap) 출처는 이 페이지에
// 모아 마이페이지 → "데이터 출처 및 라이선스"에서 상시 볼 수 있게 함. 서버 정적 페이지라 문구가
// 바뀌어도 스토어 재배포 없이 갱신 가능(troubleshooting.ts와 같은 이유로 LegalDocument 구조 재사용).
const ko: LegalDocument = {
  title: "데이터 출처 및 라이선스",
  effectiveDate: "최근 업데이트: 2026-08-28",
  sections: [
    {
      heading: "관광 정보 및 사진",
      paragraphs: [
        "TourMon의 관광지 이름·주소·소개글·홈페이지·사진 등 관광 정보는 한국관광공사가 제공하는 TourAPI(국문 관광정보서비스, 영문 관광정보서비스)를 이용합니다.",
        "본 저작물은 한국관광공사에서 서비스하는 TourAPI를 이용하였으며, 해당 저작물은 공공데이터포털(data.go.kr)에서 공공누리 제1유형(출처표시) 조건에 따라 개방된 것입니다.",
        "출처: 한국관광공사 TourAPI (https://api.visitkorea.or.kr)",
      ],
    },
    {
      heading: "사진 이용 안내",
      paragraphs: [
        "TourAPI로 제공되는 사진은 공공누리 제1유형 및 제3유형으로 개방된 자료로, TourMon은 이를 관광지 정보 안내 목적으로 원본 그대로 표시합니다. 피사체에 대한 명예훼손·인격권 침해 등 일반 정서에 반하는 용도나 기업 CI·BI로의 이용은 한국관광공사 이용 조건에 따라 금지되어 있습니다.",
      ],
    },
    {
      heading: "지도 데이터",
      paragraphs: [
        "배경 지도는 OpenStreetMap 데이터를 기반으로 합니다.",
        "지도 데이터 © OpenStreetMap 기여자, ODbL 라이선스로 이용 가능 (https://www.openstreetmap.org/copyright).",
      ],
    },
    {
      heading: "문의",
      paragraphs: [
        "출처 표기나 데이터 이용에 관한 문의는 {{CONTACT_EMAIL}}로 보내주세요.",
      ],
    },
  ],
};

const en: LegalDocument = {
  title: "Data Sources & Licenses",
  effectiveDate: "Last updated: 2026-08-28",
  sections: [
    {
      heading: "Tourism information and photos",
      paragraphs: [
        "TourMon's tourism information — spot names, addresses, descriptions, homepages, and photos — is provided by the Korea Tourism Organization's TourAPI (Korean and English tourism information services).",
        "This work uses TourAPI operated by the Korea Tourism Organization. The data is released through data.go.kr under the Korea Open Government License (KOGL) Type 1, which requires attribution.",
        "Source: Korea Tourism Organization, TourAPI (https://api.visitkorea.or.kr)",
      ],
    },
    {
      heading: "About the photos",
      paragraphs: [
        "Photos supplied through TourAPI are released under KOGL Type 1 and Type 3. TourMon displays them unmodified for the purpose of informing users about tourist destinations. Per the Korea Tourism Organization's terms, the photos may not be used in ways that defame or violate the personal rights of the people shown, nor as corporate CI/BI.",
      ],
    },
    {
      heading: "Map data",
      paragraphs: [
        "The base map is built from OpenStreetMap data.",
        "Map data © OpenStreetMap contributors, available under the Open Database License (ODbL) (https://www.openstreetmap.org/copyright).",
      ],
    },
    {
      heading: "Contact",
      paragraphs: [
        "For questions about attribution or data usage, please contact us at {{CONTACT_EMAIL}}.",
      ],
    },
  ],
};

export const creditsContent: Record<LegalLocale, LegalDocument> = { ko, en };
