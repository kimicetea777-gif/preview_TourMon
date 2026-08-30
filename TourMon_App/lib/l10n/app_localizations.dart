import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @genericErrorMessage.
  ///
  /// In ko, this message translates to:
  /// **'문제가 발생했습니다: {error}'**
  String genericErrorMessage(String error);

  /// No description provided for @welcomeMessage.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님, 환영합니다'**
  String welcomeMessage(String nickname);

  /// No description provided for @nicknameDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 설정'**
  String get nicknameDialogTitle;

  /// No description provided for @nicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'도감에 표시될 닉네임'**
  String get nicknameHint;

  /// No description provided for @doneButton.
  ///
  /// In ko, this message translates to:
  /// **'완료'**
  String get doneButton;

  /// No description provided for @cancelButton.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancelButton;

  /// No description provided for @nicknameEmptyError.
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 입력해 주세요'**
  String get nicknameEmptyError;

  /// No description provided for @nicknameSaveError.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 저장에 실패했습니다: {error}'**
  String nicknameSaveError(String error);

  /// No description provided for @accountLabel.
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get accountLabel;

  /// No description provided for @loginLabel.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get loginLabel;

  /// No description provided for @loggedInAs.
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님으로 로그인되어 있습니다.'**
  String loggedInAs(String nickname);

  /// No description provided for @accountFetchError.
  ///
  /// In ko, this message translates to:
  /// **'계정 정보를 불러오지 못했습니다. 네트워크 상태를 확인해 주세요.'**
  String get accountFetchError;

  /// No description provided for @logoutButton.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get logoutButton;

  /// No description provided for @closeButton.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get closeButton;

  /// No description provided for @loggedOutMessage.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃했습니다'**
  String get loggedOutMessage;

  /// No description provided for @partnerLimitError.
  ///
  /// In ko, this message translates to:
  /// **'파트너 알은 최대 {max}개까지만 동시에 설정할 수 있습니다.'**
  String partnerLimitError(int max);

  /// No description provided for @hatchNotReadyMessage.
  ///
  /// In ko, this message translates to:
  /// **'서버에 거리 동기화가 아직 반영되지 않았습니다. 잠시 후 다시 시도해 주세요.'**
  String get hatchNotReadyMessage;

  /// No description provided for @hatchAlreadyDoneMessage.
  ///
  /// In ko, this message translates to:
  /// **'이미 부화한 알입니다.'**
  String get hatchAlreadyDoneMessage;

  /// No description provided for @hatchEggNotOnAccountMessage.
  ///
  /// In ko, this message translates to:
  /// **'이 알을 계정으로 옮기는 중입니다. 잠시 후 다시 시도해 주세요.'**
  String get hatchEggNotOnAccountMessage;

  /// No description provided for @hatchFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'부화에 실패했습니다: {error}'**
  String hatchFailedMessage(String error);

  /// No description provided for @eggInventoryTitle.
  ///
  /// In ko, this message translates to:
  /// **'알 보관함'**
  String get eggInventoryTitle;

  /// No description provided for @noEggsMessage.
  ///
  /// In ko, this message translates to:
  /// **'보관 중인 알이 없습니다. 관광지에서 알을 획득해 보세요!'**
  String get noEggsMessage;

  /// No description provided for @hatchButton.
  ///
  /// In ko, this message translates to:
  /// **'부화하기'**
  String get hatchButton;

  /// No description provided for @distanceProgress.
  ///
  /// In ko, this message translates to:
  /// **'{rarity} · {current}km/{target}km'**
  String distanceProgress(String rarity, String current, String target);

  /// No description provided for @eggInfoButtonTooltip.
  ///
  /// In ko, this message translates to:
  /// **'알 정보'**
  String get eggInfoButtonTooltip;

  /// No description provided for @partnerToggleLabel.
  ///
  /// In ko, this message translates to:
  /// **'파트너'**
  String get partnerToggleLabel;

  /// No description provided for @partnerToggleTooltip.
  ///
  /// In ko, this message translates to:
  /// **'체크하면 이 알에 걷기 거리가 쌓입니다'**
  String get partnerToggleTooltip;

  /// No description provided for @eggInfoTargetDistanceLabel.
  ///
  /// In ko, this message translates to:
  /// **'목표 거리'**
  String get eggInfoTargetDistanceLabel;

  /// No description provided for @eggInfoHatchOddsTitle.
  ///
  /// In ko, this message translates to:
  /// **'부화 시 몬스터 등급 확률'**
  String get eggInfoHatchOddsTitle;

  /// No description provided for @eggInfoLoadFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'정보를 불러오지 못했습니다: {error}'**
  String eggInfoLoadFailedMessage(String error);

  /// No description provided for @eggOddsOverviewButtonTooltip.
  ///
  /// In ko, this message translates to:
  /// **'알 등급별 확률'**
  String get eggOddsOverviewButtonTooltip;

  /// No description provided for @eggOddsOverviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'알 등급별 몬스터 확률'**
  String get eggOddsOverviewTitle;

  /// No description provided for @guestEggShelfLifeBanner.
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 않은 알은 획득 후 {days}일이 지나면 굳어서 부화할 수 없게 돼요. 로그인하면 계정에 영구 보관됩니다.'**
  String guestEggShelfLifeBanner(int days);

  /// No description provided for @guestEggExpiresInDays.
  ///
  /// In ko, this message translates to:
  /// **'{days, plural, =1{하루 뒤 굳어요} other{{days}일 뒤 굳어요}}'**
  String guestEggExpiresInDays(int days);

  /// No description provided for @guestEggExpiresTodayLabel.
  ///
  /// In ko, this message translates to:
  /// **'오늘 지나면 굳어요'**
  String get guestEggExpiresTodayLabel;

  /// No description provided for @guestEggExpiredLabel.
  ///
  /// In ko, this message translates to:
  /// **'굳어서 부화할 수 없어요'**
  String get guestEggExpiredLabel;

  /// No description provided for @guestEggExpiredHatchAttemptMessage.
  ///
  /// In ko, this message translates to:
  /// **'알이 이미 굳어버린 것 같습니다. 보관함에서 치웠어요.'**
  String get guestEggExpiredHatchAttemptMessage;

  /// No description provided for @discardExpiredEggButton.
  ///
  /// In ko, this message translates to:
  /// **'치우기'**
  String get discardExpiredEggButton;

  /// No description provided for @guestEggDiscardedMessage.
  ///
  /// In ko, this message translates to:
  /// **'굳은 알을 치웠어요.'**
  String get guestEggDiscardedMessage;

  /// No description provided for @eggInfoGuestShelfLifeNote.
  ///
  /// In ko, this message translates to:
  /// **'로그인 전이라 획득 후 {days}일까지만 부화할 수 있어요.'**
  String eggInfoGuestShelfLifeNote(int days);

  /// No description provided for @confirmButton.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirmButton;

  /// No description provided for @dexTitle.
  ///
  /// In ko, this message translates to:
  /// **'도감'**
  String get dexTitle;

  /// No description provided for @alreadyAcquiredTodayMessage.
  ///
  /// In ko, this message translates to:
  /// **'오늘은 이미 이 관광지에서 알을 받았습니다. 내일 다시 시도해 주세요.'**
  String get alreadyAcquiredTodayMessage;

  /// No description provided for @locationInvalidMessage.
  ///
  /// In ko, this message translates to:
  /// **'위치 확인 안 됨 — 관광지와 더 가까운 곳에서 다시 시도해 주세요.'**
  String get locationInvalidMessage;

  /// No description provided for @spotNotFoundMessage.
  ///
  /// In ko, this message translates to:
  /// **'해당 관광지 정보를 찾을 수 없습니다.'**
  String get spotNotFoundMessage;

  /// No description provided for @eggAcquireFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'알 획득에 실패했습니다: {error}'**
  String eggAcquireFailedMessage(String error);

  /// No description provided for @eggAcquiredMessage.
  ///
  /// In ko, this message translates to:
  /// **'{name}({rarity})을 획득했습니다!'**
  String eggAcquiredMessage(String name, String rarity);

  /// No description provided for @acquireEggButton.
  ///
  /// In ko, this message translates to:
  /// **'알 획득하기'**
  String get acquireEggButton;

  /// No description provided for @acquireEggDisabledButton.
  ///
  /// In ko, this message translates to:
  /// **'알 획득 불가'**
  String get acquireEggDisabledButton;

  /// No description provided for @eggAcquisitionDisabledMessage.
  ///
  /// In ko, this message translates to:
  /// **'숙박, 음식점, 쇼핑은 알을 획득할 수 없습니다.'**
  String get eggAcquisitionDisabledMessage;

  /// No description provided for @showMoreButton.
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get showMoreButton;

  /// No description provided for @detailLoadFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'상세정보를 불러오지 못함: {error}'**
  String detailLoadFailedMessage(String error);

  /// No description provided for @noEnglishTranslationLabel.
  ///
  /// In ko, this message translates to:
  /// **'영어 설명: 영어 번역이 없어요'**
  String get noEnglishTranslationLabel;

  /// No description provided for @dexCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{caught} / {total}'**
  String dexCountLabel(int caught, int total);

  /// No description provided for @dexProgressLabel.
  ///
  /// In ko, this message translates to:
  /// **'{caught}/{total} COLLECTED'**
  String dexProgressLabel(int caught, int total);

  /// No description provided for @dexOfflineCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{total}마리 발견'**
  String dexOfflineCountLabel(int total);

  /// No description provided for @notDiscoveredMessage.
  ///
  /// In ko, this message translates to:
  /// **'아직 발견하지 못한 몬스터입니다.'**
  String get notDiscoveredMessage;

  /// No description provided for @dexLoadFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'도감 정보를 불러오지 못했습니다: {error}'**
  String dexLoadFailedMessage(String error);

  /// No description provided for @retryButton.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retryButton;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In ko, this message translates to:
  /// **'오프라인 상태 — 이미 잡은 몬스터만 표시 중입니다. 인터넷 연결 후 아래로 당겨서 새로고침하세요.'**
  String get offlineBannerMessage;

  /// No description provided for @noMonstersMessage.
  ///
  /// In ko, this message translates to:
  /// **'아직 발견한 몬스터가 없습니다. 인터넷에 연결한 뒤 다시 시도해 보세요.'**
  String get noMonstersMessage;

  /// No description provided for @unknownSpeciesLabel.
  ///
  /// In ko, this message translates to:
  /// **'???'**
  String get unknownSpeciesLabel;

  /// No description provided for @ownedCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}마리 보유'**
  String ownedCountLabel(int count);

  /// No description provided for @acquisitionHistoryLabel.
  ///
  /// In ko, this message translates to:
  /// **'획득 기록'**
  String get acquisitionHistoryLabel;

  /// No description provided for @attributeGrass.
  ///
  /// In ko, this message translates to:
  /// **'풀'**
  String get attributeGrass;

  /// No description provided for @attributeWater.
  ///
  /// In ko, this message translates to:
  /// **'물'**
  String get attributeWater;

  /// No description provided for @attributeFire.
  ///
  /// In ko, this message translates to:
  /// **'불'**
  String get attributeFire;

  /// No description provided for @attributePsychic.
  ///
  /// In ko, this message translates to:
  /// **'초능력'**
  String get attributePsychic;

  /// No description provided for @attributeGhost.
  ///
  /// In ko, this message translates to:
  /// **'유령'**
  String get attributeGhost;

  /// No description provided for @rarityCommon.
  ///
  /// In ko, this message translates to:
  /// **'일반'**
  String get rarityCommon;

  /// No description provided for @rarityRare.
  ///
  /// In ko, this message translates to:
  /// **'희귀'**
  String get rarityRare;

  /// No description provided for @rarityEpic.
  ///
  /// In ko, this message translates to:
  /// **'서사'**
  String get rarityEpic;

  /// No description provided for @rarityLegendary.
  ///
  /// In ko, this message translates to:
  /// **'전설'**
  String get rarityLegendary;

  /// No description provided for @contentTypeAttraction.
  ///
  /// In ko, this message translates to:
  /// **'관광지'**
  String get contentTypeAttraction;

  /// No description provided for @contentTypeCulturalFacility.
  ///
  /// In ko, this message translates to:
  /// **'문화시설'**
  String get contentTypeCulturalFacility;

  /// No description provided for @contentTypeFestival.
  ///
  /// In ko, this message translates to:
  /// **'축제/공연/행사'**
  String get contentTypeFestival;

  /// No description provided for @contentTypeTravelCourse.
  ///
  /// In ko, this message translates to:
  /// **'여행코스'**
  String get contentTypeTravelCourse;

  /// No description provided for @contentTypeLeisureSports.
  ///
  /// In ko, this message translates to:
  /// **'레포츠'**
  String get contentTypeLeisureSports;

  /// No description provided for @contentTypeAccommodation.
  ///
  /// In ko, this message translates to:
  /// **'숙박'**
  String get contentTypeAccommodation;

  /// No description provided for @contentTypeShopping.
  ///
  /// In ko, this message translates to:
  /// **'쇼핑'**
  String get contentTypeShopping;

  /// No description provided for @contentTypeRestaurant.
  ///
  /// In ko, this message translates to:
  /// **'음식점'**
  String get contentTypeRestaurant;

  /// No description provided for @duplicateSpotsLoadFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'목록을 불러오지 못했습니다: {error}'**
  String duplicateSpotsLoadFailedMessage(String error);

  /// No description provided for @moveToCurrentLocationTooltip.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치로 이동'**
  String get moveToCurrentLocationTooltip;

  /// No description provided for @stopFollowingLocationTooltip.
  ///
  /// In ko, this message translates to:
  /// **'위치 추적 끄기'**
  String get stopFollowingLocationTooltip;

  /// No description provided for @mapFollowPausedSpeedMessage.
  ///
  /// In ko, this message translates to:
  /// **'속도가 빨라 위치 추적을 잠시 멈췄어요'**
  String get mapFollowPausedSpeedMessage;

  /// No description provided for @locationServiceDisabledMessage.
  ///
  /// In ko, this message translates to:
  /// **'위치 서비스를 켜 주세요.'**
  String get locationServiceDisabledMessage;

  /// No description provided for @locationPermissionDeniedMessage.
  ///
  /// In ko, this message translates to:
  /// **'이 기능을 사용하려면 위치 권한이 필요합니다.'**
  String get locationPermissionDeniedMessage;

  /// No description provided for @locationPermissionDeniedForeverMessage.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 영구적으로 거부돼 있어요. 기기 설정 > 앱 > 권한에서 위치를 허용해 주세요.'**
  String get locationPermissionDeniedForeverMessage;

  /// No description provided for @outOfServiceAreaMessage.
  ///
  /// In ko, this message translates to:
  /// **'서울·인천 서비스 지역 밖이에요. 이 지역에서는 지도가 정상적으로 표시되지 않아요.'**
  String get outOfServiceAreaMessage;

  /// No description provided for @locationTrackingStoppedMessage.
  ///
  /// In ko, this message translates to:
  /// **'위치 접근이 중단돼 위치 추적을 멈췄어요.'**
  String get locationTrackingStoppedMessage;

  /// No description provided for @tourismDataSyncingMessage.
  ///
  /// In ko, this message translates to:
  /// **'관광지 데이터를 받는 중...'**
  String get tourismDataSyncingMessage;

  /// No description provided for @tourismDataSyncFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'관광지 데이터를 받아오지 못했습니다.'**
  String get tourismDataSyncFailedMessage;

  /// No description provided for @myPageTitle.
  ///
  /// In ko, this message translates to:
  /// **'마이페이지'**
  String get myPageTitle;

  /// No description provided for @guestBannerMessage.
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 진행 상황을 안전하게 보관할 수 있어요'**
  String get guestBannerMessage;

  /// No description provided for @editNicknameTooltip.
  ///
  /// In ko, this message translates to:
  /// **'닉네임 수정'**
  String get editNicknameTooltip;

  /// No description provided for @languageSectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageSectionTitle;

  /// No description provided for @languageDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'언어 선택'**
  String get languageDialogTitle;

  /// No description provided for @languageSystemOption.
  ///
  /// In ko, this message translates to:
  /// **'시스템 언어 사용'**
  String get languageSystemOption;

  /// No description provided for @languageKoreanOption.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get languageKoreanOption;

  /// No description provided for @languageEnglishOption.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get languageEnglishOption;

  /// No description provided for @appNotWorkingLabel.
  ///
  /// In ko, this message translates to:
  /// **'앱이 안돼요'**
  String get appNotWorkingLabel;

  /// No description provided for @tourismResyncTitle.
  ///
  /// In ko, this message translates to:
  /// **'관광지 데이터 다시 동기화'**
  String get tourismResyncTitle;

  /// No description provided for @tourismResyncSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'지도에 관광지가 제대로 안 보이면 눌러보세요'**
  String get tourismResyncSubtitle;

  /// No description provided for @tourismResyncSuccessMessage.
  ///
  /// In ko, this message translates to:
  /// **'관광지 데이터를 새로 받았습니다. 앱을 껐다 다시 켜주세요.'**
  String get tourismResyncSuccessMessage;

  /// No description provided for @partnerEggDistanceLabel.
  ///
  /// In ko, this message translates to:
  /// **'{current}km/{target}km'**
  String partnerEggDistanceLabel(String current, String target);

  /// No description provided for @emptyPartnerSlotLabel.
  ///
  /// In ko, this message translates to:
  /// **'빈 슬롯'**
  String get emptyPartnerSlotLabel;

  /// No description provided for @todayCaloriesLabel.
  ///
  /// In ko, this message translates to:
  /// **'{kcal}kcal'**
  String todayCaloriesLabel(int kcal);

  /// No description provided for @syncDistanceNowTooltip.
  ///
  /// In ko, this message translates to:
  /// **'지금 거리 동기화'**
  String get syncDistanceNowTooltip;

  /// No description provided for @distanceRefreshInfoTooltip.
  ///
  /// In ko, this message translates to:
  /// **'거리 갱신 주기 안내'**
  String get distanceRefreshInfoTooltip;

  /// No description provided for @distanceRefreshInfoTitle.
  ///
  /// In ko, this message translates to:
  /// **'거리 갱신 주기'**
  String get distanceRefreshInfoTitle;

  /// No description provided for @distanceRefreshInfoBody.
  ///
  /// In ko, this message translates to:
  /// **'걸음 거리는 배터리 소모를 줄이기 위해 약 {minutes}분 간격으로만 갱신돼요. 지금 바로 반영하려면 새로고침 버튼(⟳)을 누르거나 목록을 아래로 당겨 주세요.'**
  String distanceRefreshInfoBody(int minutes);

  /// No description provided for @distanceRefreshEveryMinutes.
  ///
  /// In ko, this message translates to:
  /// **'배터리 절약을 위해 약 {minutes}분마다 갱신돼요'**
  String distanceRefreshEveryMinutes(int minutes);

  /// No description provided for @distanceRefreshedJustNow.
  ///
  /// In ko, this message translates to:
  /// **'방금 갱신됨'**
  String get distanceRefreshedJustNow;

  /// No description provided for @distanceRefreshedMinutesAgo.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전 갱신'**
  String distanceRefreshedMinutesAgo(int minutes);

  /// No description provided for @distanceRefreshedHoursAgo.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 전 갱신'**
  String distanceRefreshedHoursAgo(int hours);

  /// No description provided for @distanceRefreshNeverSynced.
  ///
  /// In ko, this message translates to:
  /// **'아직 갱신 안 됨'**
  String get distanceRefreshNeverSynced;

  /// No description provided for @onboardingSkipButton.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get onboardingSkipButton;

  /// No description provided for @onboardingNextButton.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get onboardingNextButton;

  /// No description provided for @onboardingStartButton.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get onboardingStartButton;

  /// No description provided for @onboardingCloseButton.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get onboardingCloseButton;

  /// No description provided for @onboardingSpotTitle.
  ///
  /// In ko, this message translates to:
  /// **'관광지에서 알 획득'**
  String get onboardingSpotTitle;

  /// No description provided for @onboardingSpotBody.
  ///
  /// In ko, this message translates to:
  /// **'지도의 관광지 마커에 가까이 가면 알을 하나 얻어요. 같은 곳은 하루에 한 번.'**
  String get onboardingSpotBody;

  /// No description provided for @onboardingPartnerTitle.
  ///
  /// In ko, this message translates to:
  /// **'파트너 알 등록'**
  String get onboardingPartnerTitle;

  /// No description provided for @onboardingPartnerBody.
  ///
  /// In ko, this message translates to:
  /// **'알 보관함에서 함께 걸을 파트너 알을 최대 2개까지 골라요.'**
  String get onboardingPartnerBody;

  /// No description provided for @onboardingWalkTitle.
  ///
  /// In ko, this message translates to:
  /// **'걸어서 거리 쌓기'**
  String get onboardingWalkTitle;

  /// No description provided for @onboardingWalkBody.
  ///
  /// In ko, this message translates to:
  /// **'걸은 거리만큼 파트너 알이 자라요. 거리는 배터리 절약을 위해 몇 분마다 갱신돼요.'**
  String get onboardingWalkBody;

  /// No description provided for @onboardingHatchTitle.
  ///
  /// In ko, this message translates to:
  /// **'부화!'**
  String get onboardingHatchTitle;

  /// No description provided for @onboardingHatchBody.
  ///
  /// In ko, this message translates to:
  /// **'목표 거리를 채우면 알이 부화하고, 몬스터가 도감에 등록돼요.'**
  String get onboardingHatchBody;

  /// No description provided for @howToPlayTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 사용법 다시 보기'**
  String get howToPlayTitle;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트가 필요해요'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In ko, this message translates to:
  /// **'이 버전은 더 이상 지원되지 않아요. 계속하려면 최신 버전으로 업데이트해 주세요.'**
  String get updateRequiredBody;

  /// No description provided for @updateRequiredButton.
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get updateRequiredButton;

  /// No description provided for @noticeDismissTooltip.
  ///
  /// In ko, this message translates to:
  /// **'공지 닫기'**
  String get noticeDismissTooltip;

  /// No description provided for @expandPartnerEggBoxTooltip.
  ///
  /// In ko, this message translates to:
  /// **'파트너 알 진행도 펼치기'**
  String get expandPartnerEggBoxTooltip;

  /// No description provided for @collapsePartnerEggBoxTooltip.
  ///
  /// In ko, this message translates to:
  /// **'파트너 알 진행도 접기'**
  String get collapsePartnerEggBoxTooltip;

  /// No description provided for @expandQuickActionsBoxTooltip.
  ///
  /// In ko, this message translates to:
  /// **'메뉴 펼치기'**
  String get expandQuickActionsBoxTooltip;

  /// No description provided for @collapseQuickActionsBoxTooltip.
  ///
  /// In ko, this message translates to:
  /// **'메뉴 접기'**
  String get collapseQuickActionsBoxTooltip;

  /// No description provided for @unlinkSectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'연동 해제'**
  String get unlinkSectionTitle;

  /// No description provided for @unlinkExplanationMessage.
  ///
  /// In ko, this message translates to:
  /// **'TourMon과의 연결을 끊으려면 계정 관리 페이지로 이동해 \'연동 서비스 관리\'에서 TourMon을 찾아 \'연결 해제\'를 눌러주세요. 연결을 해제하면 로그인은 즉시 차단되고, 보유하신 개인정보는 32일 후 파기됩니다.'**
  String get unlinkExplanationMessage;

  /// No description provided for @unlinkButtonLabel.
  ///
  /// In ko, this message translates to:
  /// **'계정 관리로 이동'**
  String get unlinkButtonLabel;

  /// No description provided for @unlinkLaunchFailedMessage.
  ///
  /// In ko, this message translates to:
  /// **'페이지를 열지 못했습니다: {error}'**
  String unlinkLaunchFailedMessage(String error);

  /// No description provided for @legalLinksSectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'약관 및 정책'**
  String get legalLinksSectionTitle;

  /// No description provided for @viewTermsOfServiceLabel.
  ///
  /// In ko, this message translates to:
  /// **'이용약관 보기'**
  String get viewTermsOfServiceLabel;

  /// No description provided for @viewPrivacyPolicyLabel.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침 보기'**
  String get viewPrivacyPolicyLabel;

  /// No description provided for @viewCreditsLabel.
  ///
  /// In ko, this message translates to:
  /// **'데이터 출처 및 라이선스 보기'**
  String get viewCreditsLabel;

  /// No description provided for @tourApiAttribution.
  ///
  /// In ko, this message translates to:
  /// **'관광정보·사진 출처: ⓒ한국관광공사 (TourAPI)'**
  String get tourApiAttribution;

  /// No description provided for @healthConnectConnectPrompt.
  ///
  /// In ko, this message translates to:
  /// **'걸은 거리가 안 잡혀요 — Health Connect 연결하기'**
  String get healthConnectConnectPrompt;

  /// No description provided for @healthConnectNoticeDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'Health Connect 연동 안내'**
  String get healthConnectNoticeDialogTitle;

  /// No description provided for @healthConnectNoticeBodyMessage.
  ///
  /// In ko, this message translates to:
  /// **'파트너 알은 실제로 걸은 거리만큼 자라나요. 이 거리는 특정 제조사 앱이 아니라, 안드로이드가 제공하는 공용 건강 데이터 저장소 \'Health Connect\'에서 가져와요(구글 핏·삼성 헬스 등 다른 건강 앱이 기록한 데이터도 여기 함께 모여요). 계속하면 Health Connect가 없는 경우 설치 화면으로, 있는 경우 권한 요청 화면으로 넘어가요.'**
  String get healthConnectNoticeBodyMessage;

  /// No description provided for @healthConnectDeniedPartnerCancelledMessage.
  ///
  /// In ko, this message translates to:
  /// **'Health Connect 권한이 없어 파트너 지정을 취소했어요. 파트너 알은 걸은 거리로 자라기 때문에 권한이 필요해요.'**
  String get healthConnectDeniedPartnerCancelledMessage;

  /// No description provided for @locationConsentDialogTitle.
  ///
  /// In ko, this message translates to:
  /// **'위치정보 및 이용 연령 확인'**
  String get locationConsentDialogTitle;

  /// No description provided for @locationConsentBodyMessage.
  ///
  /// In ko, this message translates to:
  /// **'알 획득 시 관광지 반경 확인을 위해 위치정보를 실시간으로만 사용하며 저장하지 않습니다. 위치 권한은 기기 설정에서 언제든 꺼서 동의를 철회할 수 있으며, 이 경우 알 획득 등 위치 기반 기능을 이용할 수 없습니다. 자세한 내용은 마이페이지의 개인정보처리방침을 참고하세요.'**
  String get locationConsentBodyMessage;

  /// No description provided for @locationConsentAgreeCheckboxLabel.
  ///
  /// In ko, this message translates to:
  /// **'위치정보 수집·이용에 동의합니다'**
  String get locationConsentAgreeCheckboxLabel;

  /// No description provided for @ageConsentCheckboxLabel.
  ///
  /// In ko, this message translates to:
  /// **'만 14세 이상입니다'**
  String get ageConsentCheckboxLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
