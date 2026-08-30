import 'dart:convert';

import '../../config/remote_config.dart';

/// `config/app-notice.json`(tourmon-asset-cdn)에서 받은 원격 설정. 파싱은 전부 방어적으로 —
/// 어떤 필드가 빠지거나 형식이 어긋나도 예외를 던지지 않고 안전한 기본값으로 떨어진다(원격 JSON
/// 하나가 잘못돼도 앱이 죽으면 안 됨).
class AppConfig {
  const AppConfig({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.updateUrl,
    required this.notices,
  });

  /// 이 값보다 낮은 빌드는 강제 업데이트 화면으로 막음. 0 이하면 게이트 비활성.
  final int minSupportedBuild;

  /// 최신 배포 빌드(선택적 "업데이트 있음" 힌트용, 현재는 저장만). 0이면 미설정.
  final int latestBuild;

  final String updateUrl;
  final List<AppNotice> notices;

  static AppConfig? tryParse(String jsonStr) {
    try {
      final root = jsonDecode(jsonStr);
      if (root is! Map<String, dynamic>) return null;
      final android = root['android'];
      final androidMap = android is Map<String, dynamic>
          ? android
          : const <String, dynamic>{};
      final rawNotices = root['notices'];
      final noticeList = rawNotices is List ? rawNotices : const [];
      return AppConfig(
        minSupportedBuild: _asInt(androidMap['minSupportedBuild']),
        latestBuild: _asInt(androidMap['latestBuild']),
        updateUrl:
            _asHttpsUrl(androidMap['updateUrl']) ??
            RemoteConfig.fallbackStoreUrl,
        notices: noticeList
            .whereType<Map<String, dynamic>>()
            .map(AppNotice.tryParse)
            .whereType<AppNotice>()
            .toList(growable: false),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 배너로 노출되는 개별 공지. 문구는 로케일별로 들고 있다가 표시 시점에 고름.
class AppNotice {
  const AppNotice({
    required this.id,
    required this.level,
    required this.startsAt,
    required this.endsAt,
    required this.url,
    required this.byLocale,
  });

  /// 안정적인 식별자 — 사용자가 닫으면 이 id 기준으로 다시 안 뜸. 문구만 바꿔 재노출하려면 id를 바꿔야 함.
  final String id;

  /// `info` | `warn` | `critical`. `critical`은 닫기 버튼 없이 endsAt까지(또는 업데이트까지) 유지.
  final String level;

  final DateTime? startsAt;
  final DateTime? endsAt;

  /// 있으면 배너 탭 시 외부 브라우저로 염.
  final String? url;

  /// 로케일 코드('ko'/'en') → 문구. 표시 시점에 [forLocale]로 고름.
  final Map<String, ({String title, String body})> byLocale;

  ({String title, String body}) forLocale(String languageCode) =>
      byLocale[languageCode] ??
      byLocale['ko'] ??
      byLocale['en'] ??
      (title: '', body: '');

  bool isActiveAt(DateTime now) {
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  static const _levels = {'info', 'warn', 'critical'};

  static AppNotice? tryParse(Map<String, dynamic> map) {
    final id = map['id'];
    if (id is! String || id.isEmpty) return null;
    final level = map['level'];
    if (level is! String || !_levels.contains(level)) return null;

    final byLocale = <String, ({String title, String body})>{};
    for (final code in const ['ko', 'en']) {
      final t = map[code];
      if (t is Map && t['title'] is String && t['body'] is String) {
        final title = (t['title'] as String).trim();
        final body = (t['body'] as String).trim();
        if (body.isNotEmpty) byLocale[code] = (title: title, body: body);
      }
    }
    if (byLocale.isEmpty) return null;

    return AppNotice(
      id: id,
      level: level,
      startsAt: _asDate(map['startsAt']),
      endsAt: _asDate(map['endsAt']),
      url: _asHttpsUrl(map['url']),
      byLocale: byLocale,
    );
  }
}

int _asInt(Object? v) => v is num ? v.toInt() : 0;

DateTime? _asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? _asHttpsUrl(Object? v) =>
    v is String && v.startsWith('https://') ? v : null;
