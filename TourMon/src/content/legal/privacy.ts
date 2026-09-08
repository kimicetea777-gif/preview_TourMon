import type { LegalDocument, LegalLocale } from "./types";

const ko: LegalDocument = {
  title: "개인정보처리방침",
  effectiveDate: "2026-08-31",
  sections: [
    {
      heading: "제1조 (개인정보의 수집)",
      paragraphs: [
        "TourMon 운영자(이하 \"운영자\")는 서비스를 제공하면서 이용자를 식별할 수 있는 개인정보(닉네임, 계정정보, 이메일 등)를 수집하지 않습니다. 서비스는 회원가입·로그인 절차가 없으며, 이용자의 모든 게임 데이터(보유 알·몬스터, 도감, 이동거리, 관광지 방문 기록, 파트너 알 지정 등)는 이용자의 기기 내부 저장소에만 저장되고 운영자의 서버로 전송되지 않습니다.",
        "서비스를 지원하는 서버가 이용자의 요청 과정에서 처리하는 정보는 다음과 같으며, 어느 것도 이용자를 식별할 수 있는 정보나 위치 좌표를 포함하지 않습니다.",
      ],
      list: [
        "관광지 정보 요청 — 지도에 표시할 관광지 목록과 상세정보를 받아오는 요청. 이용자에 관한 정보를 포함하지 않습니다.",
        "알 발급 확인증 발급 요청 — 알 획득 시 서버가 무기명(익명) 발급 확인증을 생성합니다. 이 요청에는 공개된 관광지의 식별번호만 포함되며, 이용자 식별정보나 위치 좌표는 포함되지 않습니다(제4조).",
      ],
    },
    {
      heading: "제1조의2 (접속 로그 등)",
      paragraphs: [
        "접속 로그, IP 주소, 기기정보 등은 운영자가 서비스 제공 목적으로 수집·보관하지 않습니다. 서비스 접속 경로를 제공하는 Cloudflare의 연결정보 처리에 관하여는 제6조에서 별도로 고지합니다.",
      ],
    },
    {
      heading: "제2조 (위치정보의 처리에 관한 사항)",
      paragraphs: [
        "「위치정보의 보호 및 이용 등에 관한 법률」에 따라 위치정보 처리에 관한 사항을 다음과 같이 고지합니다.",
      ],
      list: [
        "운영자는 이용자의 개인위치정보(GPS 좌표 및 이동 경로)를 서버로 전송받거나 저장하지 않습니다. 위치정보의 수집·이용·처리는 전적으로 이용자의 기기 내에서만 이루어집니다.",
        "위치정보 이용 목적 및 방식 — (1) 관광지 방문 반경 확인: 기기에 저장된 관광지 좌표와 현재 위치를 기기 내에서 비교합니다. (2) 이동거리 측정: 기기 내에서 좌표 간 이동량을 계산해 집계 거리(m)로 환산하고, 그 집계 값을 기기에만 저장합니다. (3) 지도상 현재 위치 표시. 어느 경우에도 좌표나 이동 경로(궤적)가 기기 밖으로 전송되지 않습니다.",
        "비정상적인 위치(mock location) 사용 여부는 기기 내에서만 확인하며, 관련 상태값 역시 서버로 전송되지 않습니다.",
        "이용자는 기기의 위치정보 접근 권한을 언제든지 해제함으로써 위치정보 수집·이용에 대한 동의를 철회할 수 있습니다. 다만 이 경우 위치 기반 기능(알 획득, 이동거리 측정 등) 이용이 제한될 수 있습니다.",
        "위치정보 관리책임자는 제9조의 개인정보 보호책임자가 겸임합니다.",
        "위치정보와 관련하여 분쟁이 발생한 경우, 이용자는 개인정보 분쟁조정위원회에 분쟁조정을 신청하거나, 관계 법령에 따라 소관 행정기관에 조정·재정을 신청할 수 있습니다.",
      ],
    },
    {
      heading: "제3조 (걸음 센서 데이터)",
      paragraphs: [
        "서비스는 앱을 사용하지 않는 동안의 이동을 이동거리에 보충하기 위해 기기의 걸음 센서 기록을 이용할 수 있습니다. 이 기록은 이용자가 기기에서 '신체 활동' 권한을 허용한 경우에만 읽으며, 외부 건강 데이터 플랫폼(Health Connect 등)을 경유하지 않고 기기 센서에서 직접 읽습니다.",
        "걸음 센서 기록은 기기 내에서 이동거리(m)로 환산되어 집계 거리 값에 합산되며, 걸음 수·센서 원본 기록·환산된 거리 값 모두 서버로 전송되지 않고 기기에만 저장됩니다.",
      ],
    },
    {
      heading: "제4조 (알 발급 확인증)",
      paragraphs: [
        "알 획득 시 서버는 무기명(익명) 알 발급 확인증을 생성합니다. 이는 서버에 저장되는 유일한 데이터로, 발급 확인증 고유번호와 해당 알의 등급·목표 이동거리 등 게임 수치만 포함하며, 이용자를 식별할 수 있는 정보나 위치 좌표, 방문한 관광지 정보는 포함하지 않습니다.",
        "알 발급 확인증은 발급일로부터 90일간 보유된 후 자동으로 삭제됩니다. 이는 비정상적인 대량 발급 등 부정 이용을 완화하기 위한 임시 기록입니다.",
      ],
    },
    {
      heading: "제5조 (개인정보의 제3자 제공)",
      paragraphs: [
        "운영자는 이용자의 개인정보를 수집하지 않으므로 제3자에게 제공하는 개인정보도 없습니다. 아래 외부 시스템으로부터 정보를 \"수집\"하는 것은 제3자 제공이 아니라 수집 출처에 해당하며, 이는 이용자 개인정보가 아닌 공개 데이터입니다.",
      ],
      list: [
        "한국관광공사 TourAPI — 관광지 정보(공공 데이터)",
      ],
    },
    {
      heading: "제6조 (개인정보 처리위탁 및 국외 이전)",
      paragraphs: [
        "운영자는 안정적인 서비스 제공을 위해 서버 접속 경로 제공(네트워크 터널링)을 Cloudflare, Inc.(미국 소재 법인)에 위탁하고 있습니다. Cloudflare는 접속 경로를 제공하는 과정에서 접속 IP 주소 등 연결정보를 국외에서 처리할 수 있으며, 운영자는 해당 정보를 별도로 수집·저장하지 않습니다.",
        "서비스가 운영되는 서버 자체는 운영자가 직접 구축·관리하며 별도 업체에 위탁하지 않습니다. 지도 타일 제공을 위한 저장소·서버는 개인정보를 포함하지 않습니다.",
      ],
      list: [
        "수탁업체: Cloudflare, Inc. / 위탁업무: 네트워크 터널링(서버 접속 경로 제공) / 보유·이용기간: 위탁계약 종료 시까지",
      ],
    },
    {
      heading: "제7조 (정보주체의 권리와 행사 방법)",
      list: [
        "운영자는 이용자를 식별할 수 있는 개인정보를 보유하지 않으므로, 운영자에 대한 열람·정정·삭제·처리정지의 대상이 되는 개인정보가 원칙적으로 존재하지 않습니다.",
        "이용자의 게임 데이터는 전부 이용자의 기기에만 저장되므로, 이용자는 앱을 삭제하거나 기기의 앱 데이터를 초기화함으로써 해당 데이터를 언제든지 완전히 삭제할 수 있습니다.",
        "개인정보 처리에 관한 문의가 있는 경우 제9조의 연락처로 문의할 수 있습니다.",
      ],
    },
    {
      heading: "제8조 (안전성 확보조치)",
      paragraphs: ["운영자는 개인정보 보호를 위해 다음과 같은 조치를 취하고 있습니다."],
      list: [
        "이용자 개인정보를 수집·저장하지 않는 것을 기본 원칙으로 하는 서비스 설계",
        "통신 구간 암호화(HTTPS/TLS) 적용",
        "서버 접근 권한 최소화",
      ],
    },
    {
      heading: "제9조 (개인정보 보호책임자)",
      paragraphs: [
        "운영자는 개인정보 처리에 관한 업무를 총괄하고 정보주체의 문의·불만·피해구제를 처리하기 위하여 아래와 같이 개인정보 보호책임자를 지정합니다.",
      ],
      list: [
        "개인정보 보호책임자: TourMon 운영자 (직위: 서비스 운영자 / 담당: 개인정보 보호 업무 총괄)",
        "연락처(이메일): {{CONTACT_EMAIL}}",
      ],
    },
    {
      heading: "제10조 (만 14세 미만 아동의 개인정보 처리)",
      paragraphs: [
        "서비스는 만 14세 미만 아동의 이용을 제한하고 있으며, 별도의 아동 개인정보를 수집하지 않습니다. 이용자는 서비스 최초 이용 시 만 14세 이상임을 자기신고 방식으로 확인합니다.",
      ],
    },
    {
      heading: "제11조 (개인정보처리방침의 변경)",
      paragraphs: [
        "이 개인정보처리방침은 법령·서비스의 변경에 따라 개정될 수 있으며, 개정 시 시행일 최소 7일 전(이용자의 권리에 중대한 영향을 미치는 변경의 경우 30일 전)부터 앱 내 공지 등을 통해 고지합니다.",
      ],
    },
  ],
};

const en: LegalDocument = {
  title: "Privacy Policy",
  effectiveDate: "2026-08-31",
  sections: [
    {
      heading: "Article 1 (Collection of Personal Data)",
      paragraphs: [
        "The TourMon operator (\"Operator\") does not collect any data that can identify a user (nickname, account information, email, etc.) in providing the Service. The Service has no registration or login procedure, and all of a user's game data (eggs and monsters held, the monster dex, distance traveled, tourist-site visit records, partner-egg selections, etc.) is stored only in local storage on the user's device and is not transmitted to the Operator's server.",
        "The information the Service's supporting server processes in the course of a user's requests is as follows, and none of it includes information that can identify a user or any location coordinates.",
      ],
      list: [
        "Tourist site data requests — requests to retrieve the list of tourist sites and their details for display on the map. These do not include any information about the user.",
        "Egg issuance voucher requests — when an egg is acquired, the server generates an anonymous issuance voucher. Such a request includes only the identifier number of a publicly available tourist site, and no user-identifying information or location coordinates (Article 4).",
      ],
    },
    {
      heading: "Article 1-1 (Access Logs, etc.)",
      paragraphs: [
        "The Operator does not collect or retain access logs, IP addresses, device information, or the like for the purpose of providing the Service. Cloudflare's processing of connection information in providing the Service's connection path is disclosed separately in Article 6.",
      ],
    },
    {
      heading: "Article 2 (Location Data Notice)",
      paragraphs: [
        "The following is disclosed regarding the processing of location data as required by South Korea's Act on the Protection, Use, etc. of Location Information.",
      ],
      list: [
        "The Operator does not receive or store users' personal location data (GPS coordinates or route). All collection, use, and processing of location data takes place entirely on the user's device.",
        "Purpose and method of using location data — (1) Verifying proximity to a tourist site: the app compares the current position with tourist-site coordinates stored on the device, on the device. (2) Measuring distance traveled: the app calculates movement between coordinates on the device, converts it to an aggregated distance value (m), and stores that aggregated value only on the device. (3) Showing the current position on the map. In none of these cases are coordinates or the route (trajectory) transmitted off the device.",
        "Whether mock (falsified) location was used is checked only on the device, and the related status value is likewise never transmitted to the server.",
        "Users may withdraw consent to the collection and use of location data at any time by revoking the device's location permission, though this may limit location-based features such as egg acquisition and distance measurement.",
        "The location information management officer is concurrently held by the Data Protection Officer named in Article 9.",
        "If a dispute arises regarding location information, users may apply for dispute mediation to the Personal Information Dispute Mediation Committee or seek mediation or adjudication from the competent authority under applicable law.",
      ],
    },
    {
      heading: "Article 3 (Step-Sensor Data)",
      paragraphs: [
        "The Service may use the device's step-sensor count to fill in movement that occurs while the app is not in use, adding it to the distance traveled. This data is read only when the user has granted the device's 'Physical activity' permission, and is read directly from the device sensor without going through any external health-data platform (such as Health Connect).",
        "Step-sensor data is converted to distance (m) on the device and added to the aggregated distance value; the step count, the raw sensor data, and the converted distance value are all kept on the device and never transmitted to the server.",
      ],
    },
    {
      heading: "Article 4 (Egg Issuance Vouchers)",
      paragraphs: [
        "When an egg is acquired, the server generates an anonymous egg issuance voucher. This is the only data stored on the server; it contains only the voucher's unique number and game values such as the egg's grade and target distance, and does not include any user-identifying information, location coordinates, or information about the tourist site visited.",
        "An egg issuance voucher is retained for 90 days from issuance and then automatically deleted. It is a temporary record used to mitigate improper use such as abnormal bulk issuance.",
      ],
    },
    {
      heading: "Article 5 (Provision of Personal Data to Third Parties)",
      paragraphs: [
        "Because the Operator does not collect users' personal data, there is no personal data provided to third parties. Receiving data from the following external system is a collection source, not a third-party disclosure, and it is public data rather than users' personal data.",
      ],
      list: [
        "Korea Tourism Organization TourAPI — tourist site information (public data)",
      ],
    },
    {
      heading: "Article 6 (Outsourcing of Processing and Cross-Border Transfer)",
      paragraphs: [
        "To provide the Service reliably, the Operator outsources the provision of the server connection path (network tunneling) to Cloudflare, Inc. (a company based in the United States). Cloudflare may process connection information such as the access IP address outside Korea in the course of providing the connection path; the Operator does not separately collect or store such information.",
        "The server on which the Service runs is directly built and managed by the Operator and is not outsourced to any company. Storage/servers used to serve map tiles do not contain personal data.",
      ],
      list: [
        "Recipient: Cloudflare, Inc. / Task: network tunneling (providing a path to reach the server) / Retention period: until the outsourcing agreement ends",
      ],
    },
    {
      heading: "Article 7 (Rights of Data Subjects and How to Exercise Them)",
      list: [
        "Because the Operator holds no data that can identify a user, there is in principle no personal data held by the Operator that would be subject to access, correction, deletion, or suspension of processing.",
        "Because all of a user's game data is stored only on the user's device, a user can completely delete that data at any time by deleting the app or resetting the app's data on the device.",
        "For inquiries regarding the processing of personal data, users may contact the Operator using the details in Article 9.",
      ],
    },
    {
      heading: "Article 8 (Security Measures)",
      paragraphs: ["The Operator takes the following measures to protect personal data:"],
      list: [
        "Designing the Service on the basic principle of not collecting or storing users' personal data",
        "Encrypting data in transit (HTTPS/TLS)",
        "Minimizing access privileges to the server",
      ],
    },
    {
      heading: "Article 9 (Data Protection Officer)",
      paragraphs: [
        "The Operator designates a Data Protection Officer as set out below to oversee personal-data processing and to handle data subjects' inquiries, complaints, and remedies.",
      ],
      list: [
        "Data Protection Officer: the TourMon Operator (Position: Service Operator / Responsibility: overall management of personal data protection)",
        "Contact (email): {{CONTACT_EMAIL}}",
      ],
    },
    {
      heading: "Article 10 (Processing of Children's Personal Data)",
      paragraphs: [
        "The Service restricts use by anyone under the age of 14 and does not separately collect children's personal data. Users self-declare that they are 14 or older the first time they use the Service.",
      ],
    },
    {
      heading: "Article 11 (Changes to This Privacy Policy)",
      paragraphs: [
        "This Privacy Policy may be revised in line with changes to laws or the Service. Any revision will be announced through in-app notices or similar means at least 7 days before its effective date (at least 30 days before, for changes that materially affect users' rights).",
      ],
    },
  ],
};

export const privacyContent: Record<LegalLocale, LegalDocument> = { ko, en };
