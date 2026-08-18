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
      '서버에 걸음수 동기화가 아직 반영되지 않았습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get hatchAlreadyDoneMessage => '이미 부화한 알입니다.';

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
  String stepsProgress(String rarity, int current, int target) {
    return '$rarity · $current/$target';
  }

  @override
  String get eggInfoButtonTooltip => '알 정보';

  @override
  String get eggInfoTargetStepsLabel => '목표 걸음 수';

  @override
  String get eggInfoHatchOddsTitle => '부화 시 몬스터 등급 확률';

  @override
  String eggInfoLoadFailedMessage(String error) {
    return '정보를 불러오지 못했습니다: $error';
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
  String get eggAcquisitionDisabledMessage => '숙박, 음식점, 쇼핑은 알을 획득할 수 없습니다.';

  @override
  String get showMoreButton => '더보기';

  @override
  String detailLoadFailedMessage(String error) {
    return '상세정보를 불러오지 못함: $error';
  }

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
  String get tourismResyncTitle => '관광지 데이터 다시 동기화';

  @override
  String get tourismResyncSubtitle => '지도에 관광지가 제대로 안 보이면 눌러보세요';

  @override
  String get tourismResyncSuccessMessage => '관광지 데이터를 새로 받았습니다. 앱을 껐다 다시 켜주세요.';

  @override
  String partnerEggStepsLabel(int current, int target) {
    return '$current/$target';
  }

  @override
  String get emptyPartnerSlotLabel => '빈 슬롯';

  @override
  String todayCaloriesLabel(int kcal) {
    return '${kcal}kcal';
  }

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
      'TourMon과의 연결을 끊으려면 계정 관리 페이지로 이동해 \'연동 서비스 관리\'에서 TourMon을 찾아 \'연결 해제\'를 눌러주세요. 연결을 해제하면 로그인이 즉시 차단됩니다.';

  @override
  String get unlinkButtonLabel => '계정 관리로 이동';

  @override
  String unlinkLaunchFailedMessage(String error) {
    return '페이지를 열지 못했습니다: $error';
  }
}
