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
  /// **'서버에 걸음수 동기화가 아직 반영되지 않았습니다. 잠시 후 다시 시도해 주세요.'**
  String get hatchNotReadyMessage;

  /// No description provided for @hatchAlreadyDoneMessage.
  ///
  /// In ko, this message translates to:
  /// **'이미 부화한 알입니다.'**
  String get hatchAlreadyDoneMessage;

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

  /// No description provided for @stepsProgress.
  ///
  /// In ko, this message translates to:
  /// **'{rarity} · {current}/{target}'**
  String stepsProgress(String rarity, int current, int target);

  /// No description provided for @eggInfoButtonTooltip.
  ///
  /// In ko, this message translates to:
  /// **'알 정보'**
  String get eggInfoButtonTooltip;

  /// No description provided for @eggInfoTargetStepsLabel.
  ///
  /// In ko, this message translates to:
  /// **'목표 걸음 수'**
  String get eggInfoTargetStepsLabel;

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

  /// No description provided for @partnerEggStepsLabel.
  ///
  /// In ko, this message translates to:
  /// **'{current}/{target}'**
  String partnerEggStepsLabel(int current, int target);

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
  /// **'TourMon과의 연결을 끊으려면 계정 관리 페이지로 이동해 \'연동 서비스 관리\'에서 TourMon을 찾아 \'연결 해제\'를 눌러주세요. 연결을 해제하면 로그인이 즉시 차단됩니다.'**
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
