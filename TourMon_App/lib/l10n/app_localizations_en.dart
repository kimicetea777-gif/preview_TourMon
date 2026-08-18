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
      'Your step count hasn\'t synced to the server yet. Please try again shortly.';

  @override
  String get hatchAlreadyDoneMessage => 'This egg has already hatched.';

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
  String stepsProgress(String rarity, int current, int target) {
    return '$rarity · $current/$target';
  }

  @override
  String get eggInfoButtonTooltip => 'Egg info';

  @override
  String get eggInfoTargetStepsLabel => 'Target steps';

  @override
  String get eggInfoHatchOddsTitle => 'Monster rarity odds on hatch';

  @override
  String eggInfoLoadFailedMessage(String error) {
    return 'Couldn\'t load info: $error';
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
  String get eggAcquisitionDisabledMessage =>
      'Lodging, restaurants, and shops don\'t offer eggs.';

  @override
  String get showMoreButton => 'More';

  @override
  String detailLoadFailedMessage(String error) {
    return 'Couldn\'t load details: $error';
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
  String get tourismResyncTitle => 'Resync tourist spot data';

  @override
  String get tourismResyncSubtitle =>
      'Tap this if spots aren\'t showing up correctly on the map';

  @override
  String get tourismResyncSuccessMessage =>
      'Tourist spot data has been refreshed. Please restart the app.';

  @override
  String partnerEggStepsLabel(int current, int target) {
    return '$current/$target';
  }

  @override
  String get emptyPartnerSlotLabel => 'Empty slot';

  @override
  String todayCaloriesLabel(int kcal) {
    return '${kcal}kcal';
  }

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
      'To disconnect TourMon from your account, go to the account management page, find TourMon under \"Connected Services\", and tap \"Disconnect\". Disconnecting blocks login immediately.';

  @override
  String get unlinkButtonLabel => 'Go to Account Management';

  @override
  String unlinkLaunchFailedMessage(String error) {
    return 'Couldn\'t open the page: $error';
  }
}
