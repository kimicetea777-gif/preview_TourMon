import 'package:flutter/material.dart';

/// 서버 API에 실어 보낼 로케일 값 — 기기(앱) 로케일 기준, 'en'이 아니면 전부 'ko'로 폴백
/// (서버 `resolveLocale()`과 동일 규칙, Document/temp.md Phase B/C 참고).
String apiLocaleOf(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'ko';
}

/// 공용 client(AuthorizedApiClient)가 없는 호출부(monster_config_api.dart, tourism_api.dart)에서
/// 쓰는 헬퍼 — 기존 쿼리파라미터를 보존하면서 `locale`만 덧붙인다.
Uri withLocale(Uri uri, String locale) {
  return uri.replace(queryParameters: {...uri.queryParameters, 'locale': locale});
}

/// 로케일이 en이고 매칭된 영문 제목이 있으면 그걸 우선 — 없으면 국문 그대로 폴백(7단계,
/// init_plan.md 4-7 섹션: "없으면 title로 폴백"). `TourismSpot`을 쓰는 화면(마커 탭 시트,
/// 좌표 중복 리스트 등)이 전부 이 규칙을 같이 따라야 언어를 바꿔도 어디서는 영문, 어디서는
/// 국문으로 보이는 불일치가 안 생긴다.
String displayTitleOf(BuildContext context, {required String title, required String? titleEn}) {
  return (apiLocaleOf(context) == 'en' && titleEn != null) ? titleEn : title;
}
