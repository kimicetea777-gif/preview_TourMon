// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String genericErrorMessage(String error) {
    return '문제가 발생했습니다: $error';
  }

  @override
  String welcomeMessage(String nickname) {
    return '$nickname님, 환영합니다';
  }

  @override
  String get nicknameDialogTitle => '닉네임 설정';

  @override
  String get nicknameHint => '도감에 표시될 닉네임';

  @override
  String get doneButton => '완료';

  @override
  String get cancelButton => '취소';

  @override
  String get nicknameEmptyError => '닉네임을 입력해 주세요';

  @override
  String nicknameSaveError(String error) {
    return '닉네임 저장에 실패했습니다: $error';
  }

  @override
  String get accountLabel => '계정';

  @override
  String get loginLabel => '로그인';

  @override
  String loggedInAs(String nickname) {
    return '$nickname님으로 로그인되어 있습니다.';
  }

  @override
  String get accountFetchError => '계정 정보를 불러오지 못했습니다. 네트워크 상태를 확인해 주세요.';

  @override
  String get logoutButton => '로그아웃';

  @override
  String get closeButton => '닫기';

  @override
  String get loggedOutMessage => '로그아웃했습니다';

  @override
  String partnerLimitError(int max) {
    return '파트너 알은 최대 $max개까지만 동시에 설정할 수 있습니다.';
  }

  @override
  String get hatchNotReadyMessage =>
      '서버에 거리 동기화가 아직 반영되지 않았습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get hatchAlreadyDoneMessage => '이미 부화한 알입니다.';

  @override
  String get hatchEggNotOnAccountMessage =>
      '이 알을 계정으로 옮기는 중입니다. 잠시 후 다시 시도해 주세요.';

  @override
  String hatchFailedMessage(String error) {
    return '부화에 실패했습니다: $error';
  }

  @override
  String get eggInventoryTitle => '알 보관함';

  @override
  String get noEggsMessage => '보관 중인 알이 없습니다. 관광지에서 알을 획득해 보세요!';

  @override
  String get hatchButton => '부화하기';

  @override
  String distanceProgress(String rarity, String current, String target) {
    return '$rarity · ${current}km/${target}km';
  }

  @override
  String get eggInfoButtonTooltip => '알 정보';

  @override
  String get partnerToggleLabel => '파트너';

  @override
  String get partnerToggleTooltip => '체크하면 이 알에 걷기 거리가 쌓입니다';

  @override
  String get eggInfoTargetDistanceLabel => '목표 거리';

  @override
  String get eggInfoHatchOddsTitle => '부화 시 몬스터 등급 확률';

  @override
  String eggInfoLoadFailedMessage(String error) {
    return '정보를 불러오지 못했습니다: $error';
  }

  @override
  String get eggOddsOverviewButtonTooltip => '알 등급별 확률';

  @override
  String get eggOddsOverviewTitle => '알 등급별 몬스터 확률';

  @override
  String guestEggShelfLifeBanner(int days) {
    return '로그인하지 않은 알은 획득 후 $days일이 지나면 굳어서 부화할 수 없게 돼요. 로그인하면 계정에 영구 보관됩니다.';
  }

  @override
  String guestEggExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days일 뒤 굳어요',
      one: '하루 뒤 굳어요',
    );
    return '$_temp0';
  }

  @override
  String get guestEggExpiresTodayLabel => '오늘 지나면 굳어요';

  @override
  String get guestEggExpiredLabel => '굳어서 부화할 수 없어요';

  @override
  String get guestEggExpiredHatchAttemptMessage =>
      '알이 이미 굳어버린 것 같습니다. 보관함에서 치웠어요.';

  @override
  String get discardExpiredEggButton => '치우기';

  @override
  String get guestEggDiscardedMessage => '굳은 알을 치웠어요.';

  @override
  String eggInfoGuestShelfLifeNote(int days) {
    return '로그인 전이라 획득 후 $days일까지만 부화할 수 있어요.';
  }

  @override
  String get confirmButton => '확인';

  @override
  String get dexTitle => '도감';

  @override
  String get alreadyAcquiredTodayMessage =>
      '오늘은 이미 이 관광지에서 알을 받았습니다. 내일 다시 시도해 주세요.';

  @override
  String get locationInvalidMessage => '위치 확인 안 됨 — 관광지와 더 가까운 곳에서 다시 시도해 주세요.';

  @override
  String get spotNotFoundMessage => '해당 관광지 정보를 찾을 수 없습니다.';

  @override
  String eggAcquireFailedMessage(String error) {
    return '알 획득에 실패했습니다: $error';
  }

  @override
  String eggAcquiredMessage(String name, String rarity) {
    return '$name($rarity)을 획득했습니다!';
  }

  @override
  String get acquireEggButton => '알 획득하기';

  @override
  String get acquireEggDisabledButton => '알 획득 불가';

  @override
  String get eggAcquisitionDisabledMessage => '숙박, 음식점, 쇼핑은 알을 획득할 수 없습니다.';

  @override
  String get showMoreButton => '더보기';

  @override
  String detailLoadFailedMessage(String error) {
    return '상세정보를 불러오지 못함: $error';
  }

  @override
  String get noEnglishTranslationLabel => '영어 설명: 영어 번역이 없어요';

  @override
  String dexCountLabel(int caught, int total) {
    return '$caught / $total';
  }

  @override
  String dexProgressLabel(int caught, int total) {
    return '$caught/$total COLLECTED';
  }

  @override
  String dexOfflineCountLabel(int total) {
    return '$total마리 발견';
  }

  @override
  String get notDiscoveredMessage => '아직 발견하지 못한 몬스터입니다.';

  @override
  String dexLoadFailedMessage(String error) {
    return '도감 정보를 불러오지 못했습니다: $error';
  }

  @override
  String get retryButton => '다시 시도';

  @override
  String get offlineBannerMessage =>
      '오프라인 상태 — 이미 잡은 몬스터만 표시 중입니다. 인터넷 연결 후 아래로 당겨서 새로고침하세요.';

  @override
  String get noMonstersMessage => '아직 발견한 몬스터가 없습니다. 인터넷에 연결한 뒤 다시 시도해 보세요.';

  @override
  String get unknownSpeciesLabel => '???';

  @override
  String ownedCountLabel(int count) {
    return '$count마리 보유';
  }

  @override
  String get acquisitionHistoryLabel => '획득 기록';

  @override
  String get attributeGrass => '풀';

  @override
  String get attributeWater => '물';

  @override
  String get attributeFire => '불';

  @override
  String get attributePsychic => '초능력';

  @override
  String get attributeGhost => '유령';

  @override
  String get rarityCommon => '일반';

  @override
  String get rarityRare => '희귀';

  @override
  String get rarityEpic => '서사';

  @override
  String get rarityLegendary => '전설';

  @override
  String get contentTypeAttraction => '관광지';

  @override
  String get contentTypeCulturalFacility => '문화시설';

  @override
  String get contentTypeFestival => '축제/공연/행사';

  @override
  String get contentTypeTravelCourse => '여행코스';

  @override
  String get contentTypeLeisureSports => '레포츠';

  @override
  String get contentTypeAccommodation => '숙박';

  @override
  String get contentTypeShopping => '쇼핑';

  @override
  String get contentTypeRestaurant => '음식점';

  @override
  String duplicateSpotsLoadFailedMessage(String error) {
    return '목록을 불러오지 못했습니다: $error';
  }

  @override
  String get moveToCurrentLocationTooltip => '현재 위치로 이동';

  @override
  String get stopFollowingLocationTooltip => '위치 추적 끄기';

  @override
  String get mapFollowPausedSpeedMessage => '속도가 빨라 위치 추적을 잠시 멈췄어요';

  @override
  String get locationServiceDisabledMessage => '위치 서비스를 켜 주세요.';

  @override
  String get locationPermissionDeniedMessage => '이 기능을 사용하려면 위치 권한이 필요합니다.';

  @override
  String get locationPermissionDeniedForeverMessage =>
      '위치 권한이 영구적으로 거부돼 있어요. 기기 설정 > 앱 > 권한에서 위치를 허용해 주세요.';

  @override
  String get outOfServiceAreaMessage =>
      '서울·인천 서비스 지역 밖이에요. 이 지역에서는 지도가 정상적으로 표시되지 않아요.';

  @override
  String get locationTrackingStoppedMessage => '위치 접근이 중단돼 위치 추적을 멈췄어요.';

  @override
  String get tourismDataSyncingMessage => '관광지 데이터를 받는 중...';

  @override
  String get tourismDataSyncFailedMessage => '관광지 데이터를 받아오지 못했습니다.';

  @override
  String get myPageTitle => '마이페이지';

  @override
  String get guestBannerMessage => '로그인하면 진행 상황을 안전하게 보관할 수 있어요';

  @override
  String get editNicknameTooltip => '닉네임 수정';

  @override
  String get languageSectionTitle => '언어';

  @override
  String get languageDialogTitle => '언어 선택';

  @override
  String get languageSystemOption => '시스템 언어 사용';

  @override
  String get languageKoreanOption => '한국어';

  @override
  String get languageEnglishOption => 'English';

  @override
  String get appNotWorkingLabel => '앱이 안돼요';

  @override
  String get tourismResyncTitle => '관광지 데이터 다시 동기화';

  @override
  String get tourismResyncSubtitle => '지도에 관광지가 제대로 안 보이면 눌러보세요';

  @override
  String get tourismResyncSuccessMessage => '관광지 데이터를 새로 받았습니다. 앱을 껐다 다시 켜주세요.';

  @override
  String partnerEggDistanceLabel(String current, String target) {
    return '${current}km/${target}km';
  }

  @override
  String get emptyPartnerSlotLabel => '빈 슬롯';

  @override
  String todayCaloriesLabel(int kcal) {
    return '${kcal}kcal';
  }

  @override
  String get syncDistanceNowTooltip => '지금 거리 동기화';

  @override
  String get distanceRefreshInfoTooltip => '거리 갱신 주기 안내';

  @override
  String get distanceRefreshInfoTitle => '거리 갱신 주기';

  @override
  String distanceRefreshInfoBody(int minutes) {
    return '걸음 거리는 배터리 소모를 줄이기 위해 약 $minutes분 간격으로만 갱신돼요. 지금 바로 반영하려면 새로고침 버튼(⟳)을 누르거나 목록을 아래로 당겨 주세요.';
  }

  @override
  String distanceRefreshEveryMinutes(int minutes) {
    return '배터리 절약을 위해 약 $minutes분마다 갱신돼요';
  }

  @override
  String get distanceRefreshedJustNow => '방금 갱신됨';

  @override
  String distanceRefreshedMinutesAgo(int minutes) {
    return '$minutes분 전 갱신';
  }

  @override
  String distanceRefreshedHoursAgo(int hours) {
    return '$hours시간 전 갱신';
  }

  @override
  String get distanceRefreshNeverSynced => '아직 갱신 안 됨';

  @override
  String get onboardingSkipButton => '건너뛰기';

  @override
  String get onboardingNextButton => '다음';

  @override
  String get onboardingStartButton => '시작하기';

  @override
  String get onboardingCloseButton => '닫기';

  @override
  String get onboardingSpotTitle => '관광지에서 알 획득';

  @override
  String get onboardingSpotBody =>
      '지도의 관광지 마커에 가까이 가면 알을 하나 얻어요. 같은 곳은 하루에 한 번.';

  @override
  String get onboardingPartnerTitle => '파트너 알 등록';

  @override
  String get onboardingPartnerBody => '알 보관함에서 함께 걸을 파트너 알을 최대 2개까지 골라요.';

  @override
  String get onboardingWalkTitle => '걸어서 거리 쌓기';

  @override
  String get onboardingWalkBody =>
      '걸은 거리만큼 파트너 알이 자라요. 거리는 배터리 절약을 위해 몇 분마다 갱신돼요.';

  @override
  String get onboardingHatchTitle => '부화!';

  @override
  String get onboardingHatchBody => '목표 거리를 채우면 알이 부화하고, 몬스터가 도감에 등록돼요.';

  @override
  String get howToPlayTitle => '앱 사용법 다시 보기';

  @override
  String get updateRequiredTitle => '업데이트가 필요해요';

  @override
  String get updateRequiredBody =>
      '이 버전은 더 이상 지원되지 않아요. 계속하려면 최신 버전으로 업데이트해 주세요.';

  @override
  String get updateRequiredButton => '업데이트';

  @override
  String get noticeDismissTooltip => '공지 닫기';

  @override
  String get expandPartnerEggBoxTooltip => '파트너 알 진행도 펼치기';

  @override
  String get collapsePartnerEggBoxTooltip => '파트너 알 진행도 접기';

  @override
  String get expandQuickActionsBoxTooltip => '메뉴 펼치기';

  @override
  String get collapseQuickActionsBoxTooltip => '메뉴 접기';

  @override
  String get unlinkSectionTitle => '연동 해제';

  @override
  String get unlinkExplanationMessage =>
      'TourMon과의 연결을 끊으려면 계정 관리 페이지로 이동해 \'연동 서비스 관리\'에서 TourMon을 찾아 \'연결 해제\'를 눌러주세요. 연결을 해제하면 로그인은 즉시 차단되고, 보유하신 개인정보는 32일 후 파기됩니다.';

  @override
  String get unlinkButtonLabel => '계정 관리로 이동';

  @override
  String unlinkLaunchFailedMessage(String error) {
    return '페이지를 열지 못했습니다: $error';
  }

  @override
  String get legalLinksSectionTitle => '약관 및 정책';

  @override
  String get viewTermsOfServiceLabel => '이용약관 보기';

  @override
  String get viewPrivacyPolicyLabel => '개인정보처리방침 보기';

  @override
  String get viewCreditsLabel => '데이터 출처 및 라이선스 보기';

  @override
  String get tourApiAttribution => '관광정보·사진 출처: ⓒ한국관광공사 (TourAPI)';

  @override
  String get healthConnectConnectPrompt => '걸은 거리가 안 잡혀요 — Health Connect 연결하기';

  @override
  String get healthConnectNoticeDialogTitle => 'Health Connect 연동 안내';

  @override
  String get healthConnectNoticeBodyMessage =>
      '파트너 알은 실제로 걸은 거리만큼 자라나요. 이 거리는 특정 제조사 앱이 아니라, 안드로이드가 제공하는 공용 건강 데이터 저장소 \'Health Connect\'에서 가져와요(구글 핏·삼성 헬스 등 다른 건강 앱이 기록한 데이터도 여기 함께 모여요). 계속하면 Health Connect가 없는 경우 설치 화면으로, 있는 경우 권한 요청 화면으로 넘어가요.';

  @override
  String get healthConnectDeniedPartnerCancelledMessage =>
      'Health Connect 권한이 없어 파트너 지정을 취소했어요. 파트너 알은 걸은 거리로 자라기 때문에 권한이 필요해요.';

  @override
  String get locationConsentDialogTitle => '위치정보 및 이용 연령 확인';

  @override
  String get locationConsentBodyMessage =>
      '알 획득 시 관광지 반경 확인을 위해 위치정보를 실시간으로만 사용하며 저장하지 않습니다. 위치 권한은 기기 설정에서 언제든 꺼서 동의를 철회할 수 있으며, 이 경우 알 획득 등 위치 기반 기능을 이용할 수 없습니다. 자세한 내용은 마이페이지의 개인정보처리방침을 참고하세요.';

  @override
  String get locationConsentAgreeCheckboxLabel => '위치정보 수집·이용에 동의합니다';

  @override
  String get ageConsentCheckboxLabel => '만 14세 이상입니다';
}
