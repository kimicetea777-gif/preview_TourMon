import 'dart:convert';

import '../auth/authorized_api_client.dart';
import '../monster/monster_species.dart';

/// 서버가 아직 목표 거리 미달이라고 판단(422) — 로컬은 "준비됨"으로 보여도 서버 거리 동기화가
/// 아직 안 따라잡혀서 생길 수 있음(배치 동기화라 최대 몇 분 지연 가능, init_plan.md 4-3 참고).
class HatchNotReadyException implements Exception {}

/// 이미 부화 처리된 알(409) — 정상 플레이에선 거의 안 타는 경로(더블탭 등).
class HatchAlreadyDoneException implements Exception {}

/// 서버에 해당 알이 없을 때(404) — 자기 계정 소유가 아니거나 존재하지 않는 id.
class HatchNotFoundException implements Exception {}

/// 게스트 때 획득한 알이 아직 이 계정으로 이관되지 않아 서버에 회원 user_eggs row가 없음 —
/// 부화 직전에 재이관을 한 번 더 시도했는데도 synced 되지 않은 경우(voucher 불일치/위조 의심,
/// 혹은 이관 요청 자체가 네트워크로 실패). 서버 부화를 부르면 404(HatchNotFoundException)가 나므로
/// 그 전에 이 예외로 걸러 사용자에게 "잠시 후 재시도" 안내를 준다(egg_inventory_screen.dart).
class HatchEggNotOnAccountException implements Exception {}

/// 게스트 알의 유통기한이 지나 서버 egg_vouchers가 TTL로 사라졌고, 재이관 시도 중 로컬 row도
/// 함께 정리된 경우(migration_service.dart의 만료 정리 로직) — 보관함에서 조용히 빠진다.
class HatchEggExpiredException implements Exception {}

/// 6단계 Phase 5 — 회원 대상 서버 authoritative 부화 API 클라이언트
/// (init_plan.md 4-3 "목표 거리 달성 판정 및 부화 처리" 🖥️🔐). 게스트는 이 클래스를 쓰지 않고
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
