import 'package:flutter/material.dart';

import '../data/app_settings_repository.dart';

/// 마이페이지 "언어 선택" — 저장된 값이 있으면 그 값, 없으면 null(기기 OS locale 따라감)로
/// `MaterialApp.locale`을 채우기 위한 전역 상태. `AuthSession`(features/auth/auth_session.dart)과
/// 동일한 "ChangeNotifier + Provider" 패턴(main.dart에서 앱 전역에 노출).
///
/// `apiLocaleOf(context)`(api_locale.dart)가 이미 `Localizations.localeOf(context)`(앱의 effective
/// locale)를 읽는 구조라, 이 컨트롤러로 `MaterialApp.locale`만 채워주면 서버 API 호출도 자동으로
/// 저장된 로케일을 따라감 — 별도 배선 불필요(Document/plan/later.md "앱 내 수동 언어 선택" 참고).
class LocaleController extends ChangeNotifier {
  LocaleController({AppSettingsRepository? repository})
    : _repository = repository ?? const AppSettingsRepository();

  static const _settingKey = 'app_locale';
  static const _systemValue = 'system';

  final AppSettingsRepository _repository;

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final value = await _repository.getValue(_settingKey);
    _locale = (value == null || value == _systemValue) ? null : Locale(value);
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    await _repository.setValue(_settingKey, locale?.languageCode ?? _systemValue);
    _locale = locale;
    notifyListeners();
  }
}
