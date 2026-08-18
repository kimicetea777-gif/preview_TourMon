import 'dart:convert';

import '../auth/authorized_api_client.dart';
import '../monster/user_monster.dart';
import 'user_egg.dart';

/// 6단계 Phase 5 — 알 보관함/도감 복구(restore, `GET /api/eggs` + `GET /api/monsters/dex`).
/// 새 기기/재설치로 로컬 sqlite가 비어있어도, 로그인한 계정의 서버 데이터를 되찾아올 수 있어야
/// "로그인 = 데이터가 서버에 남는다"는 약속이 저장뿐 아니라 복구까지 완성됨
/// (Document/study_folder/6-5_... 참고).
class RestoreApi {
  const RestoreApi(this._client);

  final AuthorizedApiClient _client;

  Future<List<UserEgg>> fetchEggs() async {
    final res = await _client.get('/api/eggs');
    if (res.statusCode != 200) {
      throw Exception('Egg inventory restore failed: ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (json['eggs'] as List<dynamic>)
        .map((e) => UserEgg.fromRestoreJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserMonster>> fetchDex() async {
    final res = await _client.get('/api/monsters/dex');
    if (res.statusCode != 200) {
      throw Exception('Dex restore failed: ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (json['monsters'] as List<dynamic>)
        .map((m) => UserMonster.fromRestoreJson(m as Map<String, dynamic>))
        .toList();
  }
}
