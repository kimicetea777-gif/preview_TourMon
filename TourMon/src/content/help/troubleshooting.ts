import type { LegalDocument, LegalLocale } from "../legal/types";

// effectiveDate 필드를 "최근 업데이트"로 재사용 — 이 페이지는 법적 문서가 아니라 안드로이드
// 설정 화면 문구가 버전마다 바뀔 수 있는 troubleshooting 가이드라, LegalDocument와 같은
// 타입/컴포넌트(@/components/LegalDocument)를 그대로 재사용함(둘 다 title+날짜+섹션 목록이라는
// 동일한 문서 구조라 중복 컴포넌트를 새로 만들 이유가 없음).
//
// 거리 측정 이중화(Document/temp.md) 이후로 TourMon은 Health Connect/삼성 헬스를 전혀 쓰지 않는다.
// 주 경로는 앱이 켜져 있는 동안의 GPS 이동 거리, 보조 경로는 기기의 걸음 센서 기록이다. 위치·신체
// 활동 권한은 앱 안의 안내 배너가 그 자리에서 요청하므로 여기서 다시 다루지 않고, 앱이 인앱으로
// 못 고치는 두 가지(포그라운드 사용 습관 / OEM 배터리 관리의 백그라운드 앱 종료)만 남긴다.
const ko: LegalDocument = {
  title: "앱이 안돼요",
  effectiveDate: "최근 업데이트: 2026-08-30",
  sections: [
    {
      heading: "파트너 알 거리(오늘 거리)가 안 올라가요",
      paragraphs: [
        "TourMon은 걸은 거리를 두 가지로 측정합니다. 앱이 켜져 있는 동안은 위치(GPS) 이동 거리를 재고, 앱이 꺼져 있던 동안의 이동은 기기의 걸음 센서 기록으로 채웁니다. 별도의 건강 앱(삼성 헬스 등)이나 Health Connect는 쓰지 않습니다.",
        "위치 권한이나 신체 활동(걸음 기록) 권한이 없으면, 지도 화면 왼쪽 위 파트너 알 박스에 안내 배너가 떠요. 그 배너를 눌러 바로 허용하면 됩니다. 그래도 거리가 안 늘면 아래를 확인해 주세요.",
      ],
    },
    {
      heading: "1. 걸으면서 앱을 켜 두기",
      paragraphs: [
        "가장 확실한 방법은 지도 화면을 켜 둔 채로 걷는 것입니다. 앱이 켜져 있으면 위치로 이동 거리를 실시간에 가깝게 잽니다. 화면을 꺼도 앱이 백그라운드에 살아 있는 동안은 걸음 센서로 이동이 보충되지만, 안드로이드가 배터리를 아끼려고 앱을 완전히 종료하면 그 구간 일부는 유실될 수 있습니다.",
      ],
    },
    {
      heading: "2. 배터리 최적화에서 TourMon 제외",
      paragraphs: [
        "설정 > 배터리 및 디바이스 케어 > 배터리 > 백그라운드 사용량 제한에서 TourMon이 '절전 모드 앱'/'딥 슬립 앱' 목록에 들어가 있지 않은지 확인하세요. 안 보이면 설정 > 앱 > TourMon > 배터리에서 '제한 없음'으로 바꿔 주세요. 이 설정이 엄격하면 화면을 끄자마자 앱이 종료돼, 걸음 센서로 보충하는 구간까지 놓칠 수 있습니다. 삼성 One UI를 비롯한 여러 제조사 배터리 관리가 순정 안드로이드보다 엄격한 편이라, 최신 기기(Android 14 이상)라고 예외가 아닙니다. 메뉴 이름은 기기/버전에 따라 조금씩 다를 수 있습니다.",
      ],
    },
    {
      heading: "그래도 안 될 때",
      paragraphs: [
        "거리 수치는 배터리 절약을 위해 실시간이 아니라 몇 분 간격으로 화면에 반영됩니다. 파트너 알 박스나 알 보관함의 새로고침 버튼(⟳)을 눌러 지금 값을 바로 당겨올 수 있습니다.",
        "그래도 해결되지 않으면 {{CONTACT_EMAIL}}로 알려주세요.",
      ],
    },
  ],
};

const en: LegalDocument = {
  title: "App Not Working?",
  effectiveDate: "Last updated: 2026-08-30",
  sections: [
    {
      heading: "Partner egg distance (today's distance) isn't going up",
      paragraphs: [
        "TourMon measures your walking distance two ways. While the app is open it measures GPS movement; while the app is closed, movement is filled in from your device's step sensor. It does not use any separate health app (like Samsung Health) or Health Connect.",
        "If location or physical-activity (step tracking) permission is missing, a prompt banner appears in the partner egg box at the top left of the map screen — tap it to grant the permission on the spot. If distance still isn't increasing, check the items below.",
      ],
    },
    {
      heading: "1. Keep the app open while you walk",
      paragraphs: [
        "The most reliable approach is to keep the map screen open while walking — the app measures your movement from your location in near real time. If the screen is off but the app is still alive in the background, your steps are filled in from the step sensor, but if Android fully closes the app to save battery, part of that stretch can be lost.",
      ],
    },
    {
      heading: "2. Exclude TourMon from battery optimization",
      paragraphs: [
        "Go to Settings > Battery and device care > Battery > Background usage limits, and make sure TourMon isn't in the 'Sleeping apps' or 'Deep sleeping apps' list. If you don't see it, go to Settings > Apps > TourMon > Battery and set it to 'Unrestricted'. If this is strict, the app is killed as soon as the screen turns off, and even the step-sensor fill-in stretch can be missed. Battery management on Samsung's One UI and several other manufacturers is often stricter than stock Android, so this still applies on newer devices (Android 14+). Menu names may vary slightly by device and version.",
      ],
    },
    {
      heading: "Still not working?",
      paragraphs: [
        "To save battery, the distance shown updates every few minutes rather than in real time. Tap the refresh button (⟳) in the partner egg box or the egg inventory to pull the current value right away.",
        "If it's still not resolved, please contact us at {{CONTACT_EMAIL}}.",
      ],
    },
  ],
};

export const helpContent: Record<LegalLocale, LegalDocument> = { ko, en };
