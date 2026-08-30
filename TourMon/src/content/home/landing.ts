// 인덱스(소개) 페이지 콘텐츠 — 한국어 전용(국내 대상). 다른 페이지(약관/개인정보/도움말)와 달리
// locale 분기가 없으므로 LegalDocument 타입을 재사용하지 않고 이 페이지 전용 구조를 둠.

export type LandingScreenshot = {
  /** /public 기준 경로. 파일은 public/screenshots/ 에 넣을 것 (public/screenshots/README.md 참고). */
  src: string;
  alt: string;
  caption: string;
};

export type LandingFeature = {
  title: string;
  body: string;
};

export type LandingContent = {
  appName: string;
  tagline: string;
  /** 지원 플랫폼 / 배포 스토어 안내 배너. */
  notice: {
    lines: string[];
    store: {
      name: string;
      /** 스토어 등록 후 URL을 채우면 이 배너의 스토어 문구가 링크로 바뀜. 비어 있으면 문구만 노출. */
      url: string;
    };
  };
  intro: string[];
  features: LandingFeature[];
  screenshots: LandingScreenshot[];
  help: {
    prompt: string;
    cta: string;
    href: string;
  };
  footer: {
    links: { href: string; label: string }[];
    contactLabel: string;
  };
};

export const landingContent: LandingContent = {
  appName: "TourMon",
  tagline: "관광지를 방문하고 걸으면서 몬스터를 모으는 위치 기반 수집 게임",
  notice: {
    lines: ["현재 Android만 지원합니다."],
    store: {
      name: "원스토어",
      url: "",
    },
  },
  intro: [
    "TourMon은 실제 관광지 방문과 이동 거리를 게임과 엮은 모바일 앱입니다. 지도에서 주변 관광지를 찾아 직접 가보고, 그곳에서 받은 몬스터 알을 걸어 다니며 부화시켜 도감을 채웁니다.",
    "회원가입 없이 게스트 모드로 바로 시작할 수 있고, 나중에 로그인하면 그동안 모은 데이터를 계정으로 옮길 수 있습니다.",
  ],
  features: [
    {
      title: "지도에서 관광지 찾기",
      body: "OpenStreetMap 기반 지도에서 주변 관광지를 한눈에 확인합니다.",
    },
    {
      title: "방문하고 알 받기",
      body: "관광지 반경 안에 들어가면 하루에 한 번 몬스터 알을 받습니다. 어떤 알이 나올지는 열어보기 전까지 알 수 없습니다.",
    },
    {
      title: "걸어서 부화",
      body: "알을 파트너로 지정하고 실제로 걸은 거리만큼 알을 키워 부화시킵니다.",
    },
    {
      title: "도감 채우기",
      body: "부화한 몬스터가 도감에 등록됩니다. 여러 관광지를 다니며 도감을 채워 나갑니다.",
    },
  ],
  screenshots: [
    {
      src: "/screenshots/map.webp",
      alt: "배경 지도 위에 주변 관광지 마커가 표시된 TourMon 지도 화면",
      caption: "지도에서 주변 관광지 탐색",
    },
    {
      src: "/screenshots/egg.webp",
      alt: "관광지에서 획득한 몬스터 알과 부화 진행도를 보여주는 화면",
      caption: "걸은 거리만큼 자라는 알",
    },
    {
      src: "/screenshots/dex.webp",
      alt: "수집한 몬스터가 격자로 나열된 TourMon 도감 화면",
      caption: "부화한 몬스터로 채우는 도감",
    },
  ],
  help: {
    prompt: "걸음수가 안 올라가거나 앱이 정상 동작하지 않나요?",
    cta: "앱이 안돼요",
    href: "/help",
  },
  footer: {
    links: [
      { href: "/terms", label: "이용약관" },
      { href: "/privacy", label: "개인정보처리방침" },
      { href: "/credits", label: "오픈소스·데이터 출처" },
    ],
    contactLabel: "문의",
  },
};
