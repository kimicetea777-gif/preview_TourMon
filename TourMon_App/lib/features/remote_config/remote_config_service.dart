import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_info.dart';
import '../../config/remote_config.dart';
import '../../data/app_settings_repository.dart';
import 'app_config.dart';

/// 원격 설정(공지 + 최소 지원 빌드 게이트)을 들고 있는 싱글턴. [main]에서 [load]를 호출하면
/// ⑴ 캐시된 값을 즉시 반영(오프라인/첫 프레임에서도 게이트가 동작) ⑵ 네트워크로 갱신을 시도한다.
/// 변경 시 [notifyListeners] — `AppGate`가 이걸 구독해 강제 업데이트 화면/공지 배너를 그림.
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const _configCacheKey = 'remote_app_config_json';
  static const _dismissedNoticeIdsKey = 'dismissed_notice_ids';

  final _settings = const AppSettingsRepository();

  AppConfig? _config;
  Set<String> _dismissed = {};

  AppConfig? get config => _config;

  /// 설치 빌드가 원격의 `minSupportedBuild`보다 낮을 때만 true. 원격 설정을 아직 못 받았거나
  /// (`_config == null`), 게이트가 비활성(`minSupportedBuild <= 0`)이거나, 빌드 번호를 못 읽었으면
  /// (`AppInfo.buildNumber <= 0`) 절대 막지 않음 — CDN 장애로 사용자를 잠그지 않기 위한 fail-open.
  bool get updateRequired {
    final config = _config;
    if (config == null ||
        config.minSupportedBuild <= 0 ||
        AppInfo.buildNumber <= 0) {
      return false;
    }
    return AppInfo.buildNumber < config.minSupportedBuild;
  }

  String get updateUrl => _config?.updateUrl ?? RemoteConfig.fallbackStoreUrl;

  /// 지금 시각 기준 활성이면서(startsAt~endsAt) 아직 닫지 않은 첫 공지. `critical`은 닫아도 계속 뜸.
  AppNotice? get activeVisibleNotice {
    final config = _config;
    if (config == null) return null;
    final now = DateTime.now();
    for (final notice in config.notices) {
      if (!notice.isActiveAt(now)) continue;
      if (notice.level != 'critical' && _dismissed.contains(notice.id)) {
        continue;
      }
      return notice;
    }
    return null;
  }

  Future<void> dismiss(String noticeId) async {
    if (!_dismissed.add(noticeId)) return;
    await _settings.setValue(_dismissedNoticeIdsKey, _dismissed.join(','));
    notifyListeners();
  }

  Future<void> load() async {
    final rawDismissed = await _settings.getValue(_dismissedNoticeIdsKey);
    _dismissed = (rawDismissed ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();

    final cached = await _settings.getValue(_configCacheKey);
    if (cached != null) {
      final parsed = AppConfig.tryParse(cached);
      if (parsed != null) {
        _config = parsed;
        notifyListeners();
      }
    }

    await refresh();
  }

  Future<void> refresh() async {
    try {
      final res = await http
          .get(RemoteConfig.appNoticeUrl)
          .timeout(RemoteConfig.fetchTimeout);
      if (res.statusCode != 200) return;
      final parsed = AppConfig.tryParse(res.body);
      if (parsed == null) return;
      _config = parsed;
      await _settings.setValue(_configCacheKey, res.body);
      await _pruneDismissed();
      notifyListeners();
    } catch (_) {
      // 네트워크/파싱 실패 — 캐시된 값을 그대로 유지(있으면).
    }
  }

  /// 더 이상 원격에 존재하지 않는 공지 id는 닫음 목록에서 제거 — 무한정 쌓이지 않게.
  Future<void> _pruneDismissed() async {
    final live = _config?.notices.map((n) => n.id).toSet() ?? <String>{};
    final before = _dismissed.length;
    _dismissed.removeWhere((id) => !live.contains(id));
    if (_dismissed.length != before) {
      await _settings.setValue(_dismissedNoticeIdsKey, _dismissed.join(','));
    }
  }
}
