import type { LegalDocument, LegalLocale } from "./types";

const ko: LegalDocument = {
  title: "개인정보처리방침",
  effectiveDate: "2026-08-30",
  sections: [
    {
      heading: "제1조 (수집하는 개인정보 항목 및 수집 방법)",
      paragraphs: [
        "TourMon 운영자(이하 \"운영자\")는 다음과 같은 개인정보를 수집합니다. 아래 목록 외에 접속 로그, IP 주소, 기기정보 등은 운영자가 서비스 제공 목적으로 수집·보관하지 않으며, 서비스 접속 경로를 제공하는 Cloudflare의 연결정보 처리에 관하여는 제5조에서 별도로 고지합니다.",
      ],
      list: [
        "닉네임 — 회원가입/게스트→회원 전환 시 이용자가 직접 입력",
        "계정 식별자(고유 ID) — 인증 서버로부터 전달받는 sub 값(UUID). 이메일·비밀번호는 운영자가 보유하지 않으며 인증 서버가 별도로 관리합니다.",
        "위치정보(GPS 좌표) — 알 획득 시 반경 검증을 위해 실시간으로 전송받아 처리 즉시 폐기하며 저장하지 않습니다.",
        "이동거리 — Health Connect로부터 걸음 수(steps) 데이터를 전달받아 앱 내부에서 이동거리(m)로 환산한 값. 원본 GPS 이동 경로는 전달받지 않으며, 서버에는 환산된 집계 거리 값만 저장합니다.",
        "게임 기록 — 보유한 알/몬스터 정보",
      ],
    },
    {
      heading: "제2조 (개인정보의 처리 목적)",
      list: [
        "닉네임 — 서비스 내 이용자 식별 및 표시",
        "계정 식별자 — 회원 식별 및 서비스 제공",
        "위치정보 — 관광지 방문 반경 검증 및 부정 이용(위치 조작) 탐지",
        "이동거리 — 알 부화 진행도 판정",
      ],
    },
    {
      heading: "제3조 (처리 및 보유기간)",
      list: [
        "닉네임, 계정 식별자 — 회원 탈퇴 신청일로부터 약 30일(운영자의 처리 절차상 최대 32일)의 유예기간이 지난 뒤 파기(이용자를 식별할 수 있는 정보 일체 삭제)",
        "게임 기록(보유 알·몬스터), 이동거리 — 위 유예기간이 지난 뒤 이용자와 연결되는 식별자를 제거하여, 개인을 식별할 수 없는 통계용 데이터로만 전환·보존(전환 후에는 개인정보에 해당하지 않음)",
        "위치정보(GPS 좌표) — 저장하지 않으며, 반경 검증 처리 즉시 폐기",
        "알 발급 확인증 — 발급일로부터 90일간 보유 후 자동 삭제(부정 발급 방지 목적의 임시 증서)",
        "게스트 로컬 데이터 — 회원 전환 시 서버로 이전되며, 전환 전까지는 기기 내에만 저장되고 서버에는 보유하지 않음",
      ],
    },
    {
      heading: "제4조 (개인정보의 제3자 제공)",
      paragraphs: [
        "운영자는 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만 아래 외부 시스템으로부터 정보를 \"수집\"하는 것은 제3자 제공이 아니라 수집 출처에 해당합니다.",
      ],
      list: [
        "한국관광공사 TourAPI — 관광지 정보(공공 데이터로, 이용자 개인정보가 아닙니다)",
        "Health Connect — 이용자가 직접 권한을 허용한 경우에만 전달받는 걸음 수 데이터(앱이 이동거리로 환산하여 이용)",
      ],
    },
    {
      heading: "제5조 (개인정보 처리위탁)",
      paragraphs: [
        "운영자는 안정적인 서비스 제공을 위해 아래와 같이 개인정보 처리업무를 위탁하고 있습니다. 수탁업체 Cloudflare, Inc.(미국 소재 법인)는 서버 접속 경로를 제공하는 과정에서 접속 IP 주소 등 연결정보를 국외에서 처리할 수 있으며, 운영자는 해당 정보를 별도로 수집·저장하지 않습니다.",
      ],
      list: [
        "수탁업체: Cloudflare, Inc. / 위탁업무: 네트워크 터널링(서버 접속 경로 제공) / 보유·이용기간: 위탁계약 종료 시 또는 회원 탈퇴 시까지",
      ],
    },
    {
      heading: "제5조의2 (자체 운영 인프라에 대한 안내)",
      paragraphs: [
        "서비스가 운영되는 서버 자체는 운영자가 직접 구축·관리하는 서버(직접 운영)이며 별도 업체에 위탁하지 않습니다. 지도 타일 제공을 위한 저장소·서버는 개인정보를 포함하지 않으므로 위탁 대상에서 제외됩니다.",
      ],
    },
    {
      heading: "제6조 (정보주체의 권리와 행사 방법)",
      list: [
        "이용자는 언제든지 자신의 개인정보 열람, 정정, 삭제, 처리정지를 요청할 수 있습니다.",
        "인증 서버의 \"연동 서비스 관리\" 화면에서 제공하는 \"연결 해제\" 기능은 TourMon에 대한 재로그인을 차단하는 조치이며, TourMon이 보유한 개인정보(닉네임, 게임 기록 등)를 즉시 삭제하지 않습니다. 개인정보의 실제 삭제(파기)는 제7조의 절차에 따라 별도로 진행됩니다.",
        "개인정보 삭제를 원하는 이용자는 제9조의 연락처로 문의할 수 있습니다.",
      ],
    },
    {
      heading: "제7조 (개인정보의 파기 절차 및 방법)",
      paragraphs: [
        "운영자는 개인정보의 처리 목적이 달성되거나 이용자가 삭제를 요청한 경우, 아래 절차에 따라 해당 개인정보를 파기합니다.",
      ],
      list: [
        "삭제 요청에 의한 파기 — 이용자는 제9조의 연락처로 개인정보 삭제를 요청할 수 있습니다. 요청이 접수되면 본인 확인 후 지체 없이 해당 개인정보를 파기합니다.",
        "회원 탈퇴에 의한 파기 — 이용자가 인증 서버(TheBlueButter)에서 계정 탈퇴 또는 TourMon 연동 해제를 신청하면 즉시 로그인이 차단되며, 부정 이용 방지 및 운영 정책에 따른 유예기간(인증 서버 자체의 유예기간과 운영자의 처리 절차를 포함하여 약 30일, 최대 32일)이 지난 뒤 운영자가 보유한 개인정보를 파기합니다.",
        "파기 방법 — 이용자를 식별할 수 있는 정보(닉네임, 계정 식별자 등)는 기록을 재생할 수 없는 기술적 방법으로 영구 삭제합니다. 게임 기록은 이용자와 연결되는 식별자를 제거해 개인을 식별할 수 없는 통계용 데이터로 전환하며, 전환 후에는 개인정보에 해당하지 않습니다.",
      ],
    },
    {
      heading: "제8조 (안전성 확보조치)",
      paragraphs: ["운영자는 개인정보 보호를 위해 다음과 같은 조치를 취하고 있습니다."],
      list: [
        "개인정보 처리 시스템에 대한 접근 권한 최소화",
        "통신 구간 암호화(HTTPS/TLS) 적용",
        "인증 및 권한 부여는 표준 OAuth2/OIDC 프로토콜을 준수하는 별도 인증 서버를 통해 처리",
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
      heading: "제10조 (위치정보의 처리에 관한 사항)",
      paragraphs: [
        "「위치정보의 보호 및 이용 등에 관한 법률」에 따라 다음 사항을 별도로 고지합니다.",
      ],
      list: [
        "운영자는 개인위치정보를 저장하지 않으며, 알 획득 시 반경 검증을 위해 실시간으로만 이용한 후 즉시 폐기합니다.",
        "이용자는 기기의 위치정보 접근 권한을 언제든지 해제함으로써 위치정보 수집·이용에 대한 동의를 철회할 수 있습니다. 다만 이 경우 위치 기반 기능(알 획득 등) 이용이 제한될 수 있습니다.",
        "비정상적인 위치(mock location) 사용 여부는 좌표값이 아닌 부정 이용 감지 상태값으로만 제한적으로 기록되며, 이 역시 실제 좌표를 포함하지 않습니다.",
        "위치정보 관리책임자는 제9조의 개인정보 보호책임자가 겸임합니다.",
        "위치정보와 관련하여 분쟁이 발생한 경우, 이용자는 개인정보 분쟁조정위원회에 분쟁조정을 신청하거나, 관계 법령에 따라 소관 행정기관에 조정·재정을 신청할 수 있습니다.",
      ],
    },
    {
      heading: "제11조 (만 14세 미만 아동의 개인정보 처리)",
      paragraphs: [
        "서비스는 만 14세 미만 아동의 이용을 제한하고 있으며, 별도의 아동 개인정보를 수집하지 않습니다. 이용자는 서비스 최초 이용 시 만 14세 이상임을 자기신고 방식으로 확인합니다.",
      ],
    },
    {
      heading: "제12조 (이동거리 데이터 관련 안내)",
      paragraphs: [
        "서비스가 이용하는 이동거리는 Health Connect로부터 전달받은 걸음 수(steps)를 앱 내부에서 거리(m)로 환산한 값으로, 실제 이동 경로(GPS 궤적)를 추적하거나 저장하지 않습니다. 환산된 이동거리는 일반 개인정보로 분류되어 처리되며, 알 부화 진행도 판정 목적으로만 사용됩니다.",
        "TourMon은 Health Connect API를 통해 수신한 정보의 사용 및 제3자 제공에 있어 Health Connect 권한 정책의 \"제한적 사용 요건(Limited Use requirements)\"을 준수합니다.",
      ],
    },
    {
      heading: "제13조 (개인정보처리방침의 변경)",
      paragraphs: [
        "이 개인정보처리방침은 법령·서비스의 변경에 따라 개정될 수 있으며, 개정 시 시행일 최소 7일 전(이용자의 권리에 중대한 영향을 미치는 변경의 경우 30일 전)부터 앱 내 공지 등을 통해 고지합니다.",
      ],
    },
  ],
};

const en: LegalDocument = {
  title: "Privacy Policy",
  effectiveDate: "2026-08-30",
  sections: [
    {
      heading: "Article 1 (Personal Data Collected and Collection Methods)",
      paragraphs: ["The TourMon operator (\"Operator\") collects the following personal data. Beyond the items listed below, the Operator does not collect or retain access logs, IP addresses, device information, or the like for the purpose of providing the Service; Cloudflare's processing of connection information in providing the Service's connection path is disclosed separately in Article 5."],
      list: [
        "Nickname — entered directly by the user at registration or when converting from Guest to Member.",
        "Account identifier (unique ID) — the sub value (UUID) provided by the Auth Server. The Operator does not hold email addresses or passwords; these are managed separately by the Auth Server.",
        "Location data (GPS coordinates) — received in real time to verify proximity when acquiring an egg, then discarded immediately after processing and never stored.",
        "Distance traveled — step count (steps) data received from Health Connect and converted to a distance (m) value within the app. The raw GPS path is not received, and only the converted aggregated distance value is stored on the server.",
        "Game records — the eggs and monsters the user has acquired.",
      ],
    },
    {
      heading: "Article 2 (Purpose of Processing)",
      list: [
        "Nickname — identifying and displaying the user within the Service.",
        "Account identifier — identifying members and providing the Service.",
        "Location data — verifying proximity to tourist sites and detecting improper use (location spoofing).",
        "Distance traveled — determining egg-hatching progress.",
      ],
    },
    {
      heading: "Article 3 (Retention Period)",
      list: [
        "Nickname, account identifier — destroyed after a grace period of approximately 30 days (up to 32 days due to the Operator's processing schedule) from the date the account withdrawal is requested (all information that can identify the user is deleted).",
        "Game records (eggs and monsters held), distance traveled — after that grace period, the identifier linking the data to the user is removed and the data is retained only as non-identifiable statistical data (after this conversion it no longer constitutes personal data).",
        "Location data (GPS coordinates) — not stored; discarded immediately after proximity verification.",
        "Egg issuance vouchers — retained for 90 days from issuance, then automatically deleted (temporary records used to prevent fraudulent issuance).",
        "Guest local data — migrated to the server upon converting to a Member; until then it is stored only on the device and never held on the server.",
      ],
    },
    {
      heading: "Article 4 (Provision of Personal Data to Third Parties)",
      paragraphs: [
        "The Operator does not provide users' personal data to third parties. Receiving data from the following external systems is a collection source, not a third-party disclosure.",
      ],
      list: [
        "Korea Tourism Organization TourAPI — tourist site information (public data, not personal data).",
        "Health Connect — step count data received only when the user has granted permission (converted to distance by the app).",
      ],
    },
    {
      heading: "Article 5 (Outsourcing of Personal Data Processing)",
      paragraphs: [
        "To provide the Service reliably, the Operator outsources the following personal-data-related processing. The processor, Cloudflare, Inc. (a company based in the United States), may process connection information such as the access IP address outside Korea in the course of providing the connection path to the server; the Operator does not separately collect or store such information.",
      ],
      list: [
        "Recipient: Cloudflare, Inc. / Task: network tunneling (providing a path to reach the server) / Retention period: until the outsourcing agreement ends or the user withdraws, whichever is applicable.",
      ],
    },
    {
      heading: "Article 5-1 (Self-Hosted Infrastructure)",
      paragraphs: [
        "The server on which the Service runs is directly built and managed by the Operator (operated in-house) and is not outsourced to any company. Storage/servers used to serve map tiles do not contain personal data and are excluded from outsourcing.",
      ],
    },
    {
      heading: "Article 6 (Rights of Data Subjects and How to Exercise Them)",
      list: [
        "Users may request access to, correction of, deletion of, or suspension of processing of their personal data at any time.",
        "The \"disconnect\" feature in the Auth Server's \"Connected Services\" screen blocks future logins to TourMon, but does not immediately delete personal data (nickname, game records, etc.) held by TourMon. Actual deletion (destruction) of personal data follows the separate procedure described in Article 7.",
        "Users who wish to have their personal data deleted may contact the Operator using the details in Article 9.",
      ],
    },
    {
      heading: "Article 7 (Personal Data Destruction Procedure and Method)",
      paragraphs: [
        "The Operator destroys personal data according to the procedures below once the purpose of processing has been achieved or a user requests deletion.",
      ],
      list: [
        "Destruction on request — Users may request deletion of their personal data using the contact details in Article 9. Once a request is received, the Operator verifies the requester's identity and destroys the personal data without undue delay.",
        "Destruction on withdrawal — When a user applies to delete their account or to disconnect the TourMon integration on the Auth Server (TheBlueButter), login is blocked immediately, and after a grace period applied under abuse-prevention and operational policy — approximately 30 days (up to 32 days), inclusive of the Auth Server's own grace period and the Operator's processing schedule — the personal data held by the Operator is destroyed.",
        "Destruction method — Information that can identify a user (nickname, account identifier, etc.) is permanently deleted using a technical method that prevents reconstruction. Game records have the identifier linking them to the user removed and are converted to non-identifiable statistical data, which no longer constitutes personal data after conversion.",
      ],
    },
    {
      heading: "Article 8 (Security Measures)",
      paragraphs: ["The Operator takes the following measures to protect personal data:"],
      list: [
        "Minimizing access privileges to systems that process personal data.",
        "Encrypting data in transit (HTTPS/TLS).",
        "Handling authentication and authorization through a separate Auth Server that complies with standard OAuth2/OIDC protocols.",
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
      heading: "Article 10 (Location Data Notice)",
      paragraphs: [
        "The following is disclosed separately as required by South Korea's Act on the Protection, Use, etc. of Location Information.",
      ],
      list: [
        "The Operator does not store personal location data; it is used only in real time to verify proximity when acquiring an egg and is discarded immediately afterward.",
        "Users may withdraw consent to the collection and use of location data at any time by revoking the device's location permission, though this may limit location-based features such as egg acquisition.",
        "Whether mock (falsified) location was used is recorded only as a limited fraud-detection status value, not as coordinate values, and never includes actual location data.",
        "The location information management officer is concurrently held by the Data Protection Officer named in Article 9.",
        "If a dispute arises regarding location information, users may apply for dispute mediation to the Personal Information Dispute Mediation Committee or seek mediation or adjudication from the competent authority under applicable law.",
      ],
    },
    {
      heading: "Article 11 (Processing of Children's Personal Data)",
      paragraphs: [
        "The Service restricts use by anyone under the age of 14 and does not separately collect children's personal data. Users self-declare that they are 14 or older the first time they use the Service.",
      ],
    },
    {
      heading: "Article 12 (Notice on Distance-Traveled Data)",
      paragraphs: [
        "The distance data used by the Service is a distance (m) value converted within the app from step count (steps) data received from Health Connect; it does not track or store the user's actual GPS route. The converted distance is treated as ordinary personal data and is used only to determine egg-hatching progress.",
        "TourMon complies with the \"Limited Use\" requirements of the Health Connect permissions policy regarding the use and any third-party disclosure of information received via the Health Connect API.",
      ],
    },
    {
      heading: "Article 13 (Changes to This Privacy Policy)",
      paragraphs: [
        "This Privacy Policy may be revised in line with changes to laws or the Service. Any revision will be announced through in-app notices or similar means at least 7 days before its effective date (at least 30 days before, for changes that materially affect users' rights).",
      ],
    },
  ],
};

export const privacyContent: Record<LegalLocale, LegalDocument> = { ko, en };
