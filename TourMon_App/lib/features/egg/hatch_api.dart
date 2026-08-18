import 'dart:convert';

import '../auth/authorized_api_client.dart';
import '../monster/monster_species.dart';

/// 서버가 아직 목표 걸음수 미달이라고 판단(422) — 로컬은 "준비됨"으로 보여도 서버 걸음수 동기화가
/// 아직 안 따라잡혀서 생길 수 있음(배치 동기화라 최대 몇 분 지연 가능, init_plan.md 4-3 참고).
class HatchNotReadyException implements Exception {}

/// 이미 부화 처리된 알(409) — 정상 플레이에선 거의 안 타는 경로(더블탭 등).
class HatchAlreadyDoneException implements Exception {}

/// 서버에 해당 알이 없을 때(404) — 자기 계정 소유가 아니거나 존재하지 않는 id.
class HatchNotFoundException implements Exception {}

/// 6단계 Phase 5 — 회원 대상 서버 authoritative 부화 API 클라이언트
/// (init_plan.md 4-3 "목표 걸음수 달성 판정 및 부화 처리" 🖥️🔐). 게스트는 이 클래스를 쓰지 않고
/// 기존처럼 로컬 determineMonster()를 그대로 씀(egg_inventory_screen.dart 참고).
class HatchApi {
  const HatchApi(this._client);

  final AuthorizedApiClient _client;

  Future<MonsterSpecies> hatch(String eggId) async {
    final res = await _client.post('/api/eggs/$eggId/hatch');

    if (res.statusCode == 404) throw HatchNotFoundException();
    if (res.statusCode == 409) throw HatchAlreadyDoneException();
    if (res.statusCode == 422) throw HatchNotReadyException();
    if (res.statusCode != 200) {
      throw Exception('Hatch request failed: ${res.statusCode}');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return MonsterSpecies(
      id: json['monsterSpeciesId'] as int,
      attribute: json['attribute'] as String,
      rarity: json['rarity'] as String,
      dexNumber: json['dexNumber'] as int,
      imageUrl: json['imageUrl'] as String,
      animationUrl: json['animationUrl'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}
