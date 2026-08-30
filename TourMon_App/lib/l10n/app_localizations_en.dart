// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String genericErrorMessage(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String welcomeMessage(String nickname) {
    return 'Welcome, $nickname!';
  }

  @override
  String get nicknameDialogTitle => 'Set Nickname';

  @override
  String get nicknameHint => 'Nickname shown in your Dex';

  @override
  String get doneButton => 'Done';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get nicknameEmptyError => 'Please enter a nickname';

  @override
  String nicknameSaveError(String error) {
    return 'Failed to save nickname: $error';
  }

  @override
  String get accountLabel => 'Account';

  @override
  String get loginLabel => 'Log in';

  @override
  String loggedInAs(String nickname) {
    return 'Logged in as $nickname.';
  }

  @override
  String get accountFetchError =>
      'Couldn\'t load account info. Please check your network connection.';

  @override
  String get logoutButton => 'Log out';

  @override
  String get closeButton => 'Close';

  @override
  String get loggedOutMessage => 'Logged out';

  @override
  String partnerLimitError(int max) {
    return 'You can only set up to $max partner eggs at once.';
  }

  @override
  String get hatchNotReadyMessage =>
      'Your distance hasn\'t synced to the server yet. Please try again shortly.';

  @override
  String get hatchAlreadyDoneMessage => 'This egg has already hatched.';

  @override
  String get hatchEggNotOnAccountMessage =>
      'This egg is still being linked to your account. Please try again shortly.';

  @override
  String hatchFailedMessage(String error) {
    return 'Hatching failed: $error';
  }

  @override
  String get eggInventoryTitle => 'Egg Inventory';

  @override
  String get noEggsMessage =>
      'No eggs in your inventory. Visit a tourist spot to get one!';

  @override
  String get hatchButton => 'Hatch';

  @override
  String distanceProgress(String rarity, String current, String target) {
    return '$rarity · ${current}km/${target}km';
  }

  @override
  String get eggInfoButtonTooltip => 'Egg info';

  @override
  String get partnerToggleLabel => 'Partner';

  @override
  String get partnerToggleTooltip =>
      'Check to accumulate walking distance on this egg';

  @override
  String get eggInfoTargetDistanceLabel => 'Target distance';

  @override
  String get eggInfoHatchOddsTitle => 'Monster rarity odds on hatch';

  @override
  String eggInfoLoadFailedMessage(String error) {
    return 'Couldn\'t load info: $error';
  }

  @override
  String get eggOddsOverviewButtonTooltip => 'Odds by egg grade';

  @override
  String get eggOddsOverviewTitle => 'Monster odds by egg grade';

  @override
  String guestEggShelfLifeBanner(int days) {
    return 'Until you sign in, an egg hardens and can no longer hatch $days days after you get it. Sign in to keep your eggs on your account for good.';
  }

  @override
  String guestEggExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Hardens in $days days',
      one: 'Hardens in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get guestEggExpiresTodayLabel => 'Hardens after today';

  @override
  String get guestEggExpiredLabel => 'Hardened — can\'t hatch';

  @override
  String get guestEggExpiredHatchAttemptMessage =>
      'This egg seems to have already hardened. Removed it from your storage.';

  @override
  String get discardExpiredEggButton => 'Clear';

  @override
  String get guestEggDiscardedMessage => 'Cleared the hardened egg.';

  @override
  String eggInfoGuestShelfLifeNote(int days) {
    return 'Until you sign in, this egg can only be hatched within $days days of getting it.';
  }

  @override
  String get confirmButton => 'Confirm';

  @override
  String get dexTitle => 'Dex';

  @override
  String get alreadyAcquiredTodayMessage =>
      'You\'ve already received an egg from this spot today. Please try again tomorrow.';

  @override
  String get locationInvalidMessage =>
      'Location not verified — try again closer to the tourist spot.';

  @override
  String get spotNotFoundMessage => 'Couldn\'t find that tourist spot.';

  @override
  String eggAcquireFailedMessage(String error) {
    return 'Failed to acquire egg: $error';
  }

  @override
  String eggAcquiredMessage(String name, String rarity) {
    return 'You got $name ($rarity)!';
  }

  @override
  String get acquireEggButton => 'Get Egg';

  @override
  String get acquireEggDisabledButton => 'Egg Unavailable';

  @override
  String get eggAcquisitionDisabledMessage =>
      'Lodging, restaurants, and shops don\'t offer eggs.';

  @override
  String get showMoreButton => 'More';

  @override
  String detailLoadFailedMessage(String error) {
    return 'Couldn\'t load details: $error';
  }

  @override
  String get noEnglishTranslationLabel =>
      'English description: No English translation available';

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
    return '$total found';
  }

  @override
  String get notDiscoveredMessage =>
      'You haven\'t discovered this monster yet.';

  @override
  String dexLoadFailedMessage(String error) {
    return 'Couldn\'t load Dex info: $error';
  }

  @override
  String get retryButton => 'Retry';

  @override
  String get offlineBannerMessage =>
      'Offline — showing only monsters you\'ve already caught. Connect to the internet and pull down to refresh.';

  @override
  String get noMonstersMessage =>
      'No monsters discovered yet. Connect to the internet and try again.';

  @override
  String get unknownSpeciesLabel => '???';

  @override
  String ownedCountLabel(int count) {
    return 'Owned: $count';
  }

  @override
  String get acquisitionHistoryLabel => 'Acquisition History';

  @override
  String get attributeGrass => 'Grass';

  @override
  String get attributeWater => 'Water';

  @override
  String get attributeFire => 'Fire';

  @override
  String get attributePsychic => 'Psychic';

  @override
  String get attributeGhost => 'Ghost';

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityEpic => 'Epic';

  @override
  String get rarityLegendary => 'Legendary';

  @override
  String get contentTypeAttraction => 'Attraction';

  @override
  String get contentTypeCulturalFacility => 'Cultural Facility';

  @override
  String get contentTypeFestival => 'Festival/Event';

  @override
  String get contentTypeTravelCourse => 'Travel Course';

  @override
  String get contentTypeLeisureSports => 'Leisure Sports';

  @override
  String get contentTypeAccommodation => 'Accommodation';

  @override
  String get contentTypeShopping => 'Shopping';

  @override
  String get contentTypeRestaurant => 'Restaurant';

  @override
  String duplicateSpotsLoadFailedMessage(String error) {
    return 'Failed to load list: $error';
  }

  @override
  String get moveToCurrentLocationTooltip => 'Move to current location';

  @override
  String get stopFollowingLocationTooltip => 'Stop following location';

  @override
  String get mapFollowPausedSpeedMessage =>
      'Tracking paused — you\'re moving fast';

  @override
  String get locationServiceDisabledMessage =>
      'Please enable location services.';

  @override
  String get locationPermissionDeniedMessage =>
      'Location permission is required to use this feature.';

  @override
  String get locationPermissionDeniedForeverMessage =>
      'Location permission is permanently denied. Enable it in your device Settings > Apps > Permissions.';

  @override
  String get outOfServiceAreaMessage =>
      'You\'re outside the Seoul/Incheon service area — the map won\'t display correctly here.';

  @override
  String get locationTrackingStoppedMessage =>
      'Location tracking stopped — location access was interrupted.';

  @override
  String get tourismDataSyncingMessage => 'Downloading tourist spot data...';

  @override
  String get tourismDataSyncFailedMessage =>
      'Couldn\'t download tourist spot data.';

  @override
  String get myPageTitle => 'My Page';

  @override
  String get guestBannerMessage => 'Log in to keep your progress safe';

  @override
  String get editNicknameTooltip => 'Edit nickname';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageDialogTitle => 'Select language';

  @override
  String get languageSystemOption => 'Use system language';

  @override
  String get languageKoreanOption => 'Korean';

  @override
  String get languageEnglishOption => 'English';

  @override
  String get appNotWorkingLabel => 'App not working?';

  @override
  String get tourismResyncTitle => 'Resync tourist spot data';

  @override
  String get tourismResyncSubtitle =>
      'Tap this if spots aren\'t showing up correctly on the map';

  @override
  String get tourismResyncSuccessMessage =>
      'Tourist spot data has been refreshed. Please restart the app.';

  @override
  String partnerEggDistanceLabel(String current, String target) {
    return '${current}km/${target}km';
  }

  @override
  String get emptyPartnerSlotLabel => 'Empty slot';

  @override
  String todayCaloriesLabel(int kcal) {
    return '${kcal}kcal';
  }

  @override
  String get syncDistanceNowTooltip => 'Sync distance now';

  @override
  String get distanceRefreshInfoTooltip => 'About the distance update interval';

  @override
  String get distanceRefreshInfoTitle => 'Distance update interval';

  @override
  String distanceRefreshInfoBody(int minutes) {
    return 'Walking distance updates only about every $minutes minutes to reduce battery drain. To reflect it right now, tap the refresh button (⟳) or pull the list down.';
  }

  @override
  String distanceRefreshEveryMinutes(int minutes) {
    return 'Updates about every $minutes min to save battery';
  }

  @override
  String get distanceRefreshedJustNow => 'Just updated';

  @override
  String distanceRefreshedMinutesAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String distanceRefreshedHoursAgo(int hours) {
    return 'Updated $hours hr ago';
  }

  @override
  String get distanceRefreshNeverSynced => 'Not updated yet';

  @override
  String get onboardingSkipButton => 'Skip';

  @override
  String get onboardingNextButton => 'Next';

  @override
  String get onboardingStartButton => 'Get started';

  @override
  String get onboardingCloseButton => 'Close';

  @override
  String get onboardingSpotTitle => 'Collect eggs at spots';

  @override
  String get onboardingSpotBody =>
      'Get close to a tourist spot marker on the map to pick up an egg. Once per spot each day.';

  @override
  String get onboardingPartnerTitle => 'Set a partner egg';

  @override
  String get onboardingPartnerBody =>
      'In the egg box, pick up to 2 partner eggs to walk with.';

  @override
  String get onboardingWalkTitle => 'Walk to build distance';

  @override
  String get onboardingWalkBody =>
      'Your partner eggs grow with every step. Distance updates every few minutes to save battery.';

  @override
  String get onboardingHatchTitle => 'Hatch!';

  @override
  String get onboardingHatchBody =>
      'Fill the target distance and the egg hatches — the monster joins your collection.';

  @override
  String get howToPlayTitle => 'How to play';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version is no longer supported. Please update to the latest version to continue.';

  @override
  String get updateRequiredButton => 'Update';

  @override
  String get noticeDismissTooltip => 'Dismiss notice';

  @override
  String get expandPartnerEggBoxTooltip => 'Expand partner egg progress';

  @override
  String get collapsePartnerEggBoxTooltip => 'Collapse partner egg progress';

  @override
  String get expandQuickActionsBoxTooltip => 'Expand menu';

  @override
  String get collapseQuickActionsBoxTooltip => 'Collapse menu';

  @override
  String get unlinkSectionTitle => 'Unlink Account';

  @override
  String get unlinkExplanationMessage =>
      'To disconnect TourMon from your account, go to the account management page, find TourMon under \"Connected Services\", and tap \"Disconnect\". Disconnecting blocks login immediately, and your personal data will be destroyed after 32 days.';

  @override
  String get unlinkButtonLabel => 'Go to Account Management';

  @override
  String unlinkLaunchFailedMessage(String error) {
    return 'Couldn\'t open the page: $error';
  }

  @override
  String get legalLinksSectionTitle => 'Terms & Policies';

  @override
  String get viewTermsOfServiceLabel => 'View Terms of Service';

  @override
  String get viewPrivacyPolicyLabel => 'View Privacy Policy';

  @override
  String get viewCreditsLabel => 'View Data Sources & Licenses';

  @override
  String get tourApiAttribution =>
      'Tourism info & photos: ⓒ Korea Tourism Organization (TourAPI)';

  @override
  String get healthConnectConnectPrompt =>
      'Distance isn\'t counting — connect Health Connect';

  @override
  String get healthConnectNoticeDialogTitle => 'Health Connect Access';

  @override
  String get healthConnectNoticeBodyMessage =>
      'Partner eggs grow based on the distance you actually walk. That distance comes from Health Connect — Android\'s shared, manufacturer-independent health data store (data recorded by other health apps like Google Fit or Samsung Health also flows into it, not just one maker\'s app). Continuing will take you to the Health Connect install screen if it\'s missing, or a permission request if it\'s already installed.';

  @override
  String get healthConnectDeniedPartnerCancelledMessage =>
      'Partner assignment cancelled — Health Connect access is required, since partner eggs grow from the distance you walk.';

  @override
  String get locationConsentDialogTitle => 'Location Data & Age Confirmation';

  @override
  String get locationConsentBodyMessage =>
      'When you acquire an egg, TourMon uses your location in real time only to verify you\'re near the tourist spot, and does not store it. You can withdraw this consent anytime by turning off location permission in your device settings, though this will disable egg acquisition and other location-based features. See the Privacy Policy on the My Page screen for details.';

  @override
  String get locationConsentAgreeCheckboxLabel =>
      'I agree to the collection and use of location data';

  @override
  String get ageConsentCheckboxLabel => 'I am 14 years of age or older';
}
