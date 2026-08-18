import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// 서버가 내려주는 `monster_attribute`/`rarity_tier` ENUM 원시값(예: "grass", "common")을
/// 로케일에 맞는 표시 문구로 바꾼다. 몬스터/알 이름 자체는 이미 서버가 로케일별로 번역해서
/// 내려주지만(monster_species_translations/egg_type_translations, Document/temp.md Phase B),
/// 속성/희귀도는 구조적 ENUM이라 번역 테이블이 없어서 클라이언트에서 고정 매핑으로 처리.
String attributeLabel(BuildContext context, String attribute) {
  final l10n = AppLocalizations.of(context)!;
  switch (attribute) {
    case 'grass':
      return l10n.attributeGrass;
    case 'water':
      return l10n.attributeWater;
    case 'fire':
      return l10n.attributeFire;
    case 'psychic':
      return l10n.attributePsychic;
    case 'ghost':
      return l10n.attributeGhost;
    default:
      return attribute;
  }
}

String rarityLabel(BuildContext context, String rarity) {
  final l10n = AppLocalizations.of(context)!;
  switch (rarity) {
    case 'common':
      return l10n.rarityCommon;
    case 'rare':
      return l10n.rarityRare;
    case 'epic':
      return l10n.rarityEpic;
    case 'legendary':
      return l10n.rarityLegendary;
    default:
      return rarity;
  }
}

/// TourAPI 국문 content_type 코드(DB `content_types.id`, 12/14/15/25/28/32/38/39 고정값 —
/// schema.ts tourism_spots.contentTypeId 주석 참고)를 로케일에 맞는 표시 문구로 바꾼다.
/// 서버 `content_types` 테이블은 국문 name만 갖고 있어서(영문은 foreignCode뿐, 이름 없음),
/// attribute/rarity와 동일하게 클라이언트 고정 매핑으로 처리.
String contentTypeLabel(BuildContext context, int contentTypeId) {
  final l10n = AppLocalizations.of(context)!;
  switch (contentTypeId) {
    case 12:
      return l10n.contentTypeAttraction;
    case 14:
      return l10n.contentTypeCulturalFacility;
    case 15:
      return l10n.contentTypeFestival;
    case 25:
      return l10n.contentTypeTravelCourse;
    case 28:
      return l10n.contentTypeLeisureSports;
    case 32:
      return l10n.contentTypeAccommodation;
    case 38:
      return l10n.contentTypeShopping;
    case 39:
      return l10n.contentTypeRestaurant;
    default:
      return '$contentTypeId';
  }
}

/// 숙박(32)/쇼핑(38)/음식점(39)은 "관광지"로 보기 애매해 지도엔 표시하되 알 획득만 막음
/// (2026-08-18 결정). 서버 `content_types.egg_acquisition_enabled`가 authoritative 판정이고,
/// 이건 그 값을 클라이언트에서 미리 보여주기 위한 고정 매핑 — contentTypeLabel/Icon과 동일하게
/// TourAPI content_type 코드가 고정값이라 클라이언트에 하드코딩해도 서버와 어긋날 일이 없음.
bool canAcquireEgg(int contentTypeId) {
  switch (contentTypeId) {
    case 32:
    case 38:
    case 39:
      return false;
    default:
      return true;
  }
}

/// contentTypeLabel과 짝을 이루는 아이콘 매핑 — 좌표 중복 리스트의 카테고리 선택 UI
/// (duplicate_spots_sheet.dart)에서 텍스트 대신 아이콘으로 빠르게 구분하기 위함.
IconData contentTypeIcon(int contentTypeId) {
  switch (contentTypeId) {
    case 12:
      return Icons.attractions;
    case 14:
      return Icons.museum;
    case 15:
      return Icons.celebration;
    case 25:
      return Icons.route;
    case 28:
      return Icons.sports_tennis;
    case 32:
      return Icons.hotel;
    case 38:
      return Icons.shopping_bag;
    case 39:
      return Icons.restaurant;
    default:
      return Icons.place;
  }
}
