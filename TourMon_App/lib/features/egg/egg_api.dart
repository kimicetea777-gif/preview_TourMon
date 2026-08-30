import 'dart:convert';

import '../auth/authorized_api_client.dart';

/// 서버가 위치 확인에 실패했을 때(422) — 반경 밖.
class EggLocationInvalidException implements Exception {}

/// 서버에 해당 관광지가 없을 때(404).
class EggSpotNotFoundException implements Exception {}

/// 서버 쿨타임 거부(409, 로그인 상태 전용) — 클라이언트 프리체크(EggRepository.hasAcquiredToday)를
/// 우회해서 서버가 걸러낸 경우를 위한 것. 정상 플레이에선 프리체크가 먼저 막아서 거의 안 탐
/// (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
class EggCooldownException implements Exception {}

/// 알 획득 불가 관광지 유형(숙박/음식점/쇼핑, 403) — 정상 플레이에선 버튼 자체가 비활성화되어
/// 있어(enum_labels.dart canAcquireEgg) 거의 안 타는 경로. 서버가 authoritative 판정이라 별도로 둠.
class EggAcquisitionDisabledException implements Exception {}

class AcquiredEggResult {
  final String id;
  final int eggTypeId;
  final String rarity;
  final int targetDistanceMeters;
  final String name;
  final String? description;

  AcquiredEggResult({
    required this.id,
    required this.eggTypeId,
    required this.rarity,
    required this.targetDistanceMeters,
    required this.name,
    required this.description,
  });

  factory AcquiredEggResult.fromJson(Map<String, dynamic> json) {
    return AcquiredEggResult(
      id: json['id'] as String,
      eggTypeId: json['eggTypeId'] as int,
      rarity: json['rarity'] as String,
      targetDistanceMeters: json['targetDistanceMeters'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

/// 3단계 — 알 획득 판정 API 클라이언트. 6단계 Phase 4부터 [AuthorizedApiClient]를 통해 호출 —
/// 로그인 상태면 자동으로 Authorization 헤더가 붙어 서버가 실제 user_eggs row까지 만들고,
/// 게스트면 헤더 없이 예전과 동일한 상태 없는 판정만 받음(egg_repository.dart가 로컬 저장 전담).
/// 응답의 `id`는 로그인 여부와 무관하게 항상 내려오는 egg_vouchers.id — 로컬 user_eggs.id로
/// 그대로 써야 나중에 마이그레이션 대조가 맞는다.
class EggApi {
  const EggApi(this._client);

  final AuthorizedApiClient _client;

  Future<AcquiredEggResult> acquireEgg({
    required int tourismSpotId,
    required double lat,
    required double lng,
  }) async {
    final res = await _client.post(
      '/api/eggs/acquire',
      body: {'tourismSpotId': tourismSpotId, 'lat': lat, 'lng': lng},
    );

    if (res.statusCode == 404) throw EggSpotNotFoundException();
    if (res.statusCode == 422) throw EggLocationInvalidException();
    if (res.statusCode == 409) throw EggCooldownException();
    if (res.statusCode == 403) throw EggAcquisitionDisabledException();
    if (res.statusCode != 200) {
      throw Exception('Egg acquire request failed: ${res.statusCode}');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AcquiredEggResult.fromJson(json);
  }
}
