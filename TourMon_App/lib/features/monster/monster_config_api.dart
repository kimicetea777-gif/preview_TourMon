import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../l10n/api_locale.dart';
import 'monster_species.dart';

/// `GET /api/monsters/config` 클라이언트. 서버가 이미 인메모리 캐싱하므로(4-4 섹션) 여기서는
/// 앱 세션 동안만 재사용하는 가벼운 캐시만 둠(재실행 시 매번 새로 받아옴 — 지금 규모에서 충분).
/// 7단계 — locale별로 캐시를 따로 둠(서버 쪽과 동일한 이유, Document/temp.md Phase B/C 참고).
class MonsterConfigApi {
  const MonsterConfigApi();

  static final Map<String, MonsterConfig> _cached = {};

  Future<MonsterConfig> fetchConfig({String locale = 'ko', bool forceRefresh = false}) async {
    if (!forceRefresh && _cached[locale] != null) return _cached[locale]!;

    final uri = withLocale(
      Uri.parse('${ApiConfig.requireBaseUrl}/api/monsters/config'),
      locale,
    );
    final res = await http.get(uri).timeout(ApiConfig.requestTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch monster config: ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final config = MonsterConfig.fromJson(json);
    _cached[locale] = config;
    return config;
  }
}
