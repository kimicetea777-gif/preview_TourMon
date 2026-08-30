import type { LegalDocument, LegalLocale } from "../legal/types";

// effectiveDate 필드를 "최근 업데이트"로 재사용 — 이 페이지는 법적 문서가 아니라 안드로이드/삼성
// One UI 설정 화면 문구가 버전마다 바뀔 수 있는 troubleshooting 가이드라, LegalDocument와 같은
// 타입/컴포넌트(@/components/LegalDocument)를 그대로 재사용함(둘 다 title+날짜+섹션 목록이라는
// 동일한 문서 구조라 중복 컴포넌트를 새로 만들 이유가 없음).
const ko: LegalDocument = {
  title: "앱이 안돼요",
  effectiveDate: "최근 업데이트: 2026-08-27",
  sections: [
    {
      heading: "파트너 알 거리(걸음수)가 안 올라가요",
      paragraphs: [
        "파트너 알은 실제로 걸은 거리만큼 자라나는데, TourMon은 이 걸음수를 직접 재는 게 아니라 안드로이드의 공용 건강 데이터 저장소인 'Health Connect'에서 가져와 거리로 환산합니다. 삼성 갤럭시 기기라면 보통 삼성 헬스 앱이 이 저장소에 걸음수를 기록해 주는데, 아래 항목 중 하나라도 꺼져 있으면 거리가 전혀 안 쌓일 수 있어요. 메뉴 이름은 기기/One UI 버전에 따라 조금씩 다를 수 있습니다.",
      ],
    },
    {
      heading: "1. 삼성 헬스 앱에서 '삼성 클라우드 동기화' 켜기",
      paragraphs: [
        "삼성 헬스 앱 > 설정(오른쪽 위 톱니바퀴 아이콘) > 삼성 클라우드 동기화를 켜주세요. 이 설정이 꺼져 있으면 삼성 헬스가 걸음수를 정상적으로 기록하고 있어도 Health Connect로 아예 동기화되지 않아, 아래 권한/배터리 설정을 다 확인해도 소용없습니다.",
        "켠 뒤에는 같은 화면의 동기화 옵션도 확인하세요. '동기화 옵션'을 'Wi-Fi 전용'이 아니라 'Wi-Fi 또는 모바일 데이터 연결 시'로 체크해야, 집 밖에서 이동 중(모바일 데이터만 연결된 상태)에도 걸음수가 Health Connect로 올라갑니다.",
      ],
    },
    {
      heading: "2. Health Connect 앱 권한 확인",
      paragraphs: [
        "Health Connect 앱(또는 설정 > 개인정보 보호 > Health Connect) > 앱 권한(또는 '액세스 허용 앱')에서 다음 두 가지를 확인하세요.",
      ],
      list: [
        "삼성 헬스 — '걸음수' 항목이 쓰기(write)로 켜져 있는지.",
        "TourMon — '걸음수' 항목이 읽기(read)로 켜져 있는지.",
      ],
    },
    {
      heading: "3. 삼성 헬스가 배터리 최적화에서 제외돼 있는지 확인",
      paragraphs: [
        "설정 > 배터리 및 디바이스 케어 > 배터리 > 백그라운드 사용량 제한에서 삼성 헬스가 '절전 모드 앱'/'딥 슬립 앱' 목록에 들어가 있지 않은지 확인하세요. 안 보이면 설정 > 앱 > 삼성 헬스 > 배터리에서 '제한 없음'으로 직접 바꿔주세요. 이 설정은 최신 기기(Android 14 이상)라고 예외가 아니며, 특히 삼성 One UI는 순정 안드로이드보다 배터리 관리가 더 엄격한 경우가 많습니다.",
      ],
    },
    {
      heading: "4. 삼성 헬스에 '신체 활동' 권한이 허용돼 있는지 확인",
      paragraphs: [
        "설정 > 앱 > 삼성 헬스 > 권한에서 '신체 활동' 항목이 허용으로 돼 있는지 확인하세요. 이 권한이 꺼져 있으면 삼성 헬스가 걸음 자체를 세지 못해서, 위 설정을 다 켜도 Health Connect까지 갈 데이터가 애초에 생기지 않습니다.",
      ],
    },
    {
      heading: "5. 그래도 안 될 때",
      paragraphs: [
        "삼성 헬스 앱을 열어서 오늘 걸음수가 정상적으로 찍히고 있는지 먼저 확인해 주세요. Health Connect는 삼성 헬스가 기록한 데이터를 전달만 하는 통로라서, 삼성 헬스 자체에 걸음이 안 찍히면 위 설정을 다 켜도 소용없습니다.",
        "그래도 해결되지 않으면 {{CONTACT_EMAIL}}로 알려주세요.",
      ],
    },
  ],
};

const en: LegalDocument = {
  title: "App Not Working?",
  effectiveDate: "Last updated: 2026-08-27",
  sections: [
    {
      heading: "Partner egg distance isn't going up",
      paragraphs: [
        "Partner eggs grow based on the distance you actually walk. TourMon doesn't measure your steps itself — it reads them from Health Connect, Android's shared health data store, and converts them to distance. On Samsung Galaxy phones, Samsung Health is usually what writes steps into that store, and if any of the settings below are off, distance may never accumulate at all. Menu names may vary slightly by device and One UI version.",
      ],
    },
    {
      heading: "1. Turn on 'Samsung Cloud Sync' in Samsung Health",
      paragraphs: [
        "Open Samsung Health > Settings (gear icon, top right) > Samsung Cloud Sync, and turn it on. If this is off, Samsung Health won't sync to Health Connect at all even if it's recording your steps correctly — none of the permission or battery settings below will help until this is on.",
        "After turning it on, also check the sync option on the same screen. Set it to 'Wi-Fi or mobile data' rather than 'Wi-Fi only', so your steps still sync to Health Connect while you're out and moving on mobile data.",
      ],
    },
    {
      heading: "2. Check Health Connect app permissions",
      paragraphs: [
        "In the Health Connect app (or Settings > Privacy > Health Connect) > App permissions, check both of these:",
      ],
      list: [
        "Samsung Health — make sure 'Steps' write access is turned on.",
        "TourMon — make sure 'Steps' read access is turned on.",
      ],
    },
    {
      heading: "3. Check that Samsung Health is excluded from battery optimization",
      paragraphs: [
        "Go to Settings > Battery and device care > Battery > Background usage limits, and make sure Samsung Health isn't in the 'Sleeping apps' or 'Deep sleeping apps' list. If you don't see it there, go to Settings > Apps > Samsung Health > Battery and set it to 'Unrestricted'. This still applies on newer devices (Android 14+) — Samsung's One UI battery management is often stricter than stock Android regardless of OS version.",
      ],
    },
    {
      heading: "4. Check that Samsung Health has the 'Physical activity' permission",
      paragraphs: [
        "Go to Settings > Apps > Samsung Health > Permissions and make sure 'Physical activity' is allowed. Without it, Samsung Health can't count steps at all, so there's nothing for Health Connect to pass along even if every other setting above is correct.",
      ],
    },
    {
      heading: "5. Still not working?",
      paragraphs: [
        "First open Samsung Health itself and check whether today's step count is showing up correctly. Health Connect only relays data that Samsung Health already recorded, so if Samsung Health itself shows no steps, the settings above won't help.",
        "If it's still not resolved, please contact us at {{CONTACT_EMAIL}}.",
      ],
    },
  ],
};

export const helpContent: Record<LegalLocale, LegalDocument> = { ko, en };
