import type { LegalDocument, LegalLocale } from "./types";

const ko: LegalDocument = {
  title: "이용약관",
  effectiveDate: "2026-08-30",
  sections: [
    {
      heading: "제1조 (목적)",
      paragraphs: [
        "이 약관은 TourMon 운영자(이하 \"운영자\")가 제공하는 위치 기반 관광 연계 몬스터 수집 게임 서비스 \"TourMon\"(모바일 애플리케이션 및 관련 API 서버를 포함하며, 이하 \"서비스\")의 이용 조건 및 절차, 운영자와 이용자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.",
      ],
    },
    {
      heading: "제1조의2 (약관의 효력 및 개정)",
      list: [
        "이 약관은 서비스 화면에 게시하는 방법으로 공지하며, 이용자가 서비스를 이용함으로써 효력이 발생합니다.",
        "운영자는 관련 법령을 위배하지 않는 범위에서 이 약관을 개정할 수 있으며, 개정 시 적용일자 및 개정 사유를 명시하여 적용일 최소 7일 전(이용자에게 불리하거나 중대한 변경의 경우 30일 전)부터 서비스 내 공지 등을 통해 공지합니다.",
        "이용자가 개정 약관의 적용일까지 거부 의사를 표시하지 않고 서비스를 계속 이용하는 경우 개정에 동의한 것으로 봅니다. 개정 약관에 동의하지 않는 이용자는 서비스 이용을 중단하고 탈퇴(회원의 경우 제11조)할 수 있습니다.",
      ],
    },
    {
      heading: "제2조 (정의)",
      list: [
        "\"서비스\"란 실제 관광지 방문과 걸음수(이동거리) 측정을 결합하여 위치 기반으로 몬스터 알을 획득·부화시키는 TourMon 모바일 애플리케이션 및 이를 지원하는 서버를 말합니다.",
        "\"이용자\"란 이 약관에 따라 운영자가 제공하는 서비스를 이용하는 회원 및 게스트를 말합니다.",
        "\"회원\"이란 운영자와 별도로 연동된 인증 서버(이하 \"인증 서버\")를 통해 계정을 생성하고 로그인하여 서비스를 이용하는 자를 말합니다.",
        "\"게스트\"란 회원가입 없이 기기 내 로컬 저장소에만 게임 데이터를 저장한 상태로 서비스를 이용하는 자를 말합니다. 게스트는 계정이 없는 상태이며, 이 약관에서 \"탈퇴\"에 관한 조항은 게스트에게 적용되지 않습니다(게스트는 앱 삭제로 이용을 종료합니다).",
      ],
    },
    {
      heading: "제3조 (계정 및 게스트 모드)",
      list: [
        "서비스는 인증 서버를 통한 회원가입 없이도 게스트 모드로 핵심 기능(지도 탐색, 알 획득·부화, 도감)을 이용할 수 있습니다.",
        "게스트가 회원으로 전환(로그인)하는 경우, 게스트 상태에서 축적한 게임 데이터는 서버로 마이그레이션될 수 있습니다.",
        "회원가입 및 로그인은 운영자가 아닌 별도의 인증 서버가 처리하며, 계정 생성·비밀번호 관리·본인 확인 등은 인증 서버의 약관 및 정책을 따릅니다.",
        "게스트 모드에서 축적한 게임 데이터는 이용자의 기기 로컬 저장소에만 보관되며, 앱 삭제, 기기 변경·분실·고장, OS 데이터 초기화 등의 사유로 영구 유실될 수 있습니다. 운영자는 이러한 게스트 데이터 유실에 대해 책임을 지지 않으며, 데이터를 안전하게 보관하려면 회원 전환(로그인)을 권장합니다.",
      ],
    },
    {
      heading: "제4조 (서비스 내용의 변경 및 중단)",
      list: [
        "운영자는 운영상, 기술상의 필요에 따라 서비스의 전부 또는 일부 내용을 변경하거나 중단할 수 있습니다.",
        "서비스 내용을 변경하거나 중단하는 경우 운영자는 사전에 이를 서비스 내 공지 등 합리적인 방법으로 공지합니다. 다만 긴급한 보안 문제 등 부득이한 경우 사후에 공지할 수 있습니다.",
      ],
    },
    {
      heading: "제4조의2 (이용 요금)",
      paragraphs: [
        "서비스는 현재 무료로 제공되며, 별도의 유료 결제 기능이 없습니다.",
      ],
    },
    {
      heading: "제5조 (이용자의 의무)",
      paragraphs: ["이용자는 다음 각 호의 행위를 하여서는 안 됩니다."],
      list: [
        "위치 정보를 조작하는 등 부정한 방법으로 서비스를 이용하는 행위(mock location 등)",
        "타인의 계정을 도용하거나 부정하게 사용하는 행위",
        "서비스의 안정적 운영을 방해하는 행위(비정상적인 요청 반복, 서버 부하 유발 등)",
        "관련 법령 및 이 약관에서 금지하는 행위",
      ],
    },
    {
      heading: "제5조의2 (위반에 대한 조치)",
      paragraphs: [
        "운영자는 이용자가 제5조 각 호를 위반한 경우, 사전 통지 없이 서비스 이용 제한, 계정 영구 정지, 부정하게 취득한 게임 데이터(알·몬스터 등)의 회수 등 필요한 조치를 취할 수 있습니다.",
      ],
    },
    {
      heading: "제6조 (지식재산권)",
      paragraphs: [
        "서비스와 관련하여 운영자가 제작한 저작물(게임 콘텐츠, 디자인, 로고 등)에 대한 지식재산권은 운영자에게 귀속됩니다. 이용자는 운영자의 사전 승낙 없이 이를 복제, 배포, 상업적으로 이용할 수 없습니다.",
      ],
    },
    {
      heading: "제6조의2 (게임 데이터의 성격 및 현금거래 금지)",
      list: [
        "이용자가 서비스 내에서 획득한 알·몬스터 등 모든 게임 데이터는 서비스 내에서만 이용할 수 있는 이용권이며, 이용자에게 소유권 또는 재산권이 인정되지 않습니다.",
        "이용자는 게임 데이터 또는 계정을 제3자에게 현금이나 그 밖의 재산상 이익을 받고 판매·양도·대여하거나 이를 청약·광고하는 행위를 하여서는 안 됩니다. 위반 시 운영자는 제5조의2에 따른 조치를 취할 수 있습니다.",
        "서비스 종료, 계정 파기, 부정 이용에 따른 회수 등으로 게임 데이터가 소멸하더라도 운영자는 이용자에게 그에 대한 금전적 보상 의무를 지지 않습니다.",
      ],
    },
    {
      heading: "제7조 (이용 연령 제한)",
      paragraphs: [
        "서비스는 만 14세 미만인 자는 이용할 수 없습니다. 이용자는 서비스 최초 이용 시 위치정보 이용 동의 절차와 함께 만 14세 이상임을 자기신고 방식으로 확인합니다.",
      ],
    },
    {
      heading: "제8조 (위치기반서비스의 이용)",
      paragraphs: [
        "서비스는 「위치정보의 보호 및 이용 등에 관한 법률」의 적용을 받는 위치기반서비스를 포함하며, 그 주요 내용은 다음과 같습니다. 위치정보 처리에 관한 그 밖의 구체적인 사항은 개인정보처리방침의 위치정보 처리에 관한 사항(별도 고지)을 따릅니다.",
      ],
      list: [
        "이용 요금 — 위치기반서비스를 포함한 서비스 전부는 무료로 제공됩니다.",
        "위치정보 이용 목적 — 관광지 방문 반경 검증, 위치 조작 등 부정 이용 탐지, 위치 기반 기능(알 획득 등)의 제공. 운영자는 개인위치정보를 저장하지 않으며 실시간 검증 후 즉시 폐기합니다.",
        "동의 철회 및 이용 일시중지 — 이용자는 기기의 위치정보 접근 권한을 해제함으로써 위치정보 이용에 대한 동의를 철회하고 그 이용을 즉시 중지시킬 수 있습니다. 다만 이 경우 위치 기반 기능의 이용이 제한됩니다.",
        "위치정보 관리책임자 및 이용자 권리의 구체적 행사 방법 — 개인정보처리방침 제10조에 따릅니다.",
        "분쟁 조정 — 위치정보와 관련하여 분쟁이 발생한 경우 이용자는 개인정보 분쟁조정위원회에 분쟁조정을 신청하거나, 관계 법령에 따라 소관 행정기관에 조정·재정을 신청할 수 있습니다.",
      ],
    },
    {
      heading: "제9조 (면책조항)",
      list: [
        "운영자는 천재지변, 이용자의 귀책사유 등 운영자가 통제할 수 없는 사유로 서비스를 제공할 수 없는 경우 책임을 지지 않습니다.",
        "운영자는 이용자가 서비스를 이용하며 얻은 정보로 인해 발생한 손해에 대해 책임을 지지 않습니다.",
        "서비스는 실외 이동을 전제로 하므로, 이용자는 서비스 이용 중 교통 및 안전에 유의하여야 하며, 이용자의 부주의로 인해 발생한 사고에 대해 운영자는 책임을 지지 않습니다.",
        "한국관광공사 TourAPI 등 외부 공공데이터를 기반으로 제공되는 관광지 정보의 정확성, 최신성 및 실제 운영 여부(폐업, 임시 휴업 등)에 대해 운영자는 보증하지 않으며, 이로 인해 발생한 손해에 대해 책임을 지지 않습니다.",
        "운영자의 고의 또는 중대한 과실이 없는 한, 운영자는 이용자에게 발생한 통상손해를 초과하는 특별손해, 간접손해 또는 결과적 손해에 대하여 책임을 지지 않습니다.",
      ],
    },
    {
      heading: "제10조 (준거법 및 관할)",
      paragraphs: [
        "이 약관과 관련한 분쟁에 대해서는 대한민국 법을 준거법으로 하며, 관할 법원은 민사소송법상의 관할 법원으로 합니다.",
      ],
    },
    {
      heading: "제11조 (회원 탈퇴)",
      paragraphs: [
        "이용자는 인증 서버(TheBlueButter)의 계정 관리 페이지에서 언제든지 계정 탈퇴를 신청할 수 있습니다. 탈퇴 신청 시 즉시 계정이 비활성화(로그인 차단)되며, 부정 이용 방지 및 운영 정책에 따라 30일간 보관 후 완전 파기됩니다. 유예기간 중에는 탈퇴 신청을 취소할 수 없습니다.",
        "이 조항은 TheBlueButter 계정 자체를 삭제하는 절차입니다. TourMon 앱과의 연동만 해제하고 계정은 그대로 유지하려면 마이페이지의 \"연동 해제\" 기능을 이용해 주세요.",
        "연동 서비스(TourMon 포함)에 남아있는 활동 기록은 TheBlueButter 계정 삭제와 별개로 각 연동 서비스의 정책에 따라 처리됩니다. TourMon이 보유한 개인정보의 구체적인 보유기간 및 파기 절차는 개인정보처리방침을 참고하세요.",
      ],
    },
    {
      heading: "제12조 (운영자 정보)",
      list: ["서비스명: TourMon", "운영 형태: 개인 운영", "문의: {{CONTACT_EMAIL}}"],
    },
  ],
};

const en: LegalDocument = {
  title: "Terms of Service",
  effectiveDate: "2026-08-30",
  sections: [
    {
      heading: "Article 1 (Purpose)",
      paragraphs: [
        "These Terms govern the conditions and procedures for using \"TourMon\" (the mobile application and its supporting API server, hereinafter the \"Service\"), a location-based tourism monster-collecting game provided by the TourMon operator (\"Operator\"), as well as the rights, obligations, and responsibilities of the Operator and users.",
      ],
    },
    {
      heading: "Article 1-1 (Effect and Amendment of These Terms)",
      list: [
        "These Terms are announced by being posted within the Service, and take effect when a user uses the Service.",
        "The Operator may amend these Terms within the bounds of applicable law. Any amendment will be announced through in-app notices or similar means, stating the effective date and the reason, at least 7 days before the effective date (at least 30 days before, for changes unfavorable to users or otherwise material).",
        "If a user continues to use the Service without expressing refusal by the effective date of the amended Terms, the user is deemed to have agreed to the amendment. A user who does not agree may stop using the Service and withdraw (for Members, under Article 11).",
      ],
    },
    {
      heading: "Article 2 (Definitions)",
      list: [
        "\"Service\" means the TourMon mobile application and its supporting server, which combine real-world tourist site visits and distance traveled to let users acquire and hatch monster eggs based on location.",
        "\"User\" means any Member or Guest who uses the Service under these Terms.",
        "\"Member\" means a person who creates an account and logs in through a separately operated authentication server (\"Auth Server\") to use the Service.",
        "\"Guest\" means a person who uses the Service with game data stored only in local on-device storage, without creating an account. A Guest has no account, and provisions of these Terms regarding \"withdrawal\" do not apply to Guests (a Guest ends use of the Service by deleting the app).",
      ],
    },
    {
      heading: "Article 3 (Accounts and Guest Mode)",
      list: [
        "The Service allows core features (map exploration, egg acquisition/hatching, the monster dex) to be used in Guest mode without registering through the Auth Server.",
        "When a Guest converts to a Member (logs in), game data accumulated as a Guest may be migrated to the server.",
        "Registration and login are handled by a separate Auth Server, not the Operator; account creation, password management, and identity verification are governed by the Auth Server's own terms and policies.",
        "Game data accumulated in Guest mode is stored only in local storage on the user's device, and may be permanently lost due to app deletion, a device change, loss, or malfunction, or an OS data reset. The Operator is not liable for such loss of Guest data; users who want their data kept safely are encouraged to convert to a Member (log in).",
      ],
    },
    {
      heading: "Article 4 (Changes to and Suspension of the Service)",
      list: [
        "The Operator may change or suspend all or part of the Service for operational or technical reasons.",
        "When changing or suspending the Service, the Operator will provide reasonable advance notice, such as an in-app notice, except where urgent circumstances (e.g., security issues) require notice to be given afterward.",
      ],
    },
    {
      heading: "Article 4-1 (Service Fees)",
      paragraphs: [
        "The Service is currently provided free of charge and has no separate paid features.",
      ],
    },
    {
      heading: "Article 5 (User Obligations)",
      paragraphs: ["Users must not engage in any of the following:"],
      list: [
        "Using the Service through improper means such as falsifying location data (e.g., mock locations)",
        "Stealing or improperly using another person's account",
        "Interfering with the stable operation of the Service (e.g., abnormal repeated requests, causing server load)",
        "Any act prohibited by applicable law or these Terms",
      ],
    },
    {
      heading: "Article 5-1 (Measures for Violations)",
      paragraphs: [
        "If a user violates any item of Article 5, the Operator may take necessary measures without prior notice, including restricting use of the Service, permanently suspending the account, and reclaiming game data (eggs, monsters, etc.) obtained improperly.",
      ],
    },
    {
      heading: "Article 6 (Intellectual Property)",
      paragraphs: [
        "Intellectual property rights in works created by the Operator in connection with the Service (game content, design, logos, etc.) belong to the Operator. Users may not reproduce, distribute, or commercially exploit such works without the Operator's prior consent.",
      ],
    },
    {
      heading: "Article 6-1 (Nature of Game Data and Prohibition of Real-Money Trading)",
      list: [
        "All game data acquired within the Service, such as eggs and monsters, is a license to use within the Service only; no ownership or property right in it is recognized for the user.",
        "Users must not sell, transfer, lend, or offer or advertise game data or accounts to third parties for cash or other financial benefit. The Operator may take measures under Article 5-1 for violations.",
        "Even if game data is lost due to termination of the Service, destruction of an account, or reclamation for improper use, the Operator bears no obligation to provide monetary compensation to the user.",
      ],
    },
    {
      heading: "Article 7 (Minimum Age)",
      paragraphs: [
        "The Service may not be used by anyone under the age of 14. Users self-declare that they are 14 or older as part of the location-data consent process the first time they use the Service.",
      ],
    },
    {
      heading: "Article 8 (Use of Location-Based Services)",
      paragraphs: [
        "The Service includes location-based services subject to South Korea's Act on the Protection, Use, etc. of Location Information. Their key terms are as follows. Other specific matters regarding the processing of location data are governed by the location data notice in the Privacy Policy.",
      ],
      list: [
        "Fees — the entire Service, including its location-based features, is provided free of charge.",
        "Purpose of using location data — verifying proximity to tourist sites, detecting improper use such as location spoofing, and providing location-based features (e.g., egg acquisition). The Operator does not store personal location data and discards it immediately after real-time verification.",
        "Withdrawal of consent and suspension of use — Users may withdraw consent to the use of location data and immediately stop such use by revoking the device's location permission; doing so will limit location-based features.",
        "The location information management officer and the specific means of exercising user rights are as set out in Article 10 of the Privacy Policy.",
        "Dispute resolution — If a dispute arises regarding location information, users may apply for dispute mediation to the Personal Information Dispute Mediation Committee or seek mediation or adjudication from the competent authority under applicable law.",
      ],
    },
    {
      heading: "Article 9 (Disclaimer)",
      list: [
        "The Operator is not liable for failure to provide the Service due to causes beyond the Operator's control, such as force majeure or causes attributable to the user.",
        "The Operator is not liable for damages arising from information a user obtains while using the Service.",
        "Because the Service is premised on outdoor movement, users must exercise caution regarding traffic and personal safety while using it; the Operator is not liable for accidents arising from a user's own inattention.",
        "The Operator does not guarantee the accuracy, currency, or actual operating status (e.g., closure or temporary suspension) of tourist site information provided based on external public data sources such as the Korea Tourism Organization's TourAPI, and is not liable for damages arising therefrom.",
        "Except in cases of the Operator's intent or gross negligence, the Operator is not liable for special, indirect, or consequential damages exceeding ordinary damages incurred by the user.",
      ],
    },
    {
      heading: "Article 10 (Governing Law and Jurisdiction)",
      paragraphs: [
        "Disputes relating to these Terms are governed by the laws of the Republic of Korea, and jurisdiction lies with the court having jurisdiction under the Civil Procedure Act.",
      ],
    },
    {
      heading: "Article 11 (Account Withdrawal)",
      paragraphs: [
        "Users may apply to delete their account at any time from the account management page of the Auth Server (TheBlueButter). Upon applying, the account is immediately deactivated (login blocked); to prevent abuse, it is retained for 30 days under Operator policy before being permanently purged. The withdrawal request cannot be canceled during this grace period.",
        "This article covers deleting the TheBlueButter account itself. If you only want to disconnect the TourMon app while keeping your account, use the \"Disconnect\" feature on the My Page screen instead.",
        "Activity records remaining with connected services (including TourMon) are handled under each service's own policy, independent of TheBlueButter account deletion. See the Privacy Policy for the specific retention period and destruction procedure for personal data held by TourMon.",
      ],
    },
    {
      heading: "Article 12 (Operator Information)",
      list: ["Service name: TourMon", "Operated by: an individual operator", "Contact: {{CONTACT_EMAIL}}"],
    },
  ],
};

export const termsContent: Record<LegalLocale, LegalDocument> = { ko, en };
