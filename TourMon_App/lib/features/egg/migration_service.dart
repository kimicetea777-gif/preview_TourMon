import 'dart:convert';
import 'dart:developer' as developer;

import '../auth/authorized_api_client.dart';
import '../monster/monster_repository.dart';
import '../monster/user_monster.dart';
import '../distance/distance_tracker_service.dart';
import 'egg_repository.dart';
import 'restore_api.dart';
import 'user_egg.dart';

/// 서버가 각 알/몬스터에 대해 돌려주는 개별 판정 결과. `rejected`가 아닌 것(migrated/already_done)은
/// 서버 반영이 확인된 것이므로 로컬에서 synced_at을 채운다. `rejected`(voucher 불일치/위조 의심 등)는
/// 로컬에 그대로 두고 로그만 남김 — 다음 로그인에 자연히 재시도된다.
class MigrationOutcome {
  const MigrationOutcome({required this.id, required this.status});

  final String id;
  final String status; // 'migrated' | 'already_done' | 'rejected'

  bool get isConfirmed => status != 'rejected';
}

class MigrationResult {
  const MigrationResult({required this.eggs, required this.monsters});

  final List<MigrationOutcome> eggs;
  final List<MigrationOutcome> monsters;

  static List<MigrationOutcome> _parse(dynamic list) =>
      (list as List<dynamic>? ?? [])
          .map(
            (e) => MigrationOutcome(
              id: (e as Map<String, dynamic>)['id'] as String,
              status: e['status'] as String,
            ),
          )
          .toList();

  factory MigrationResult.fromJson(Map<String, dynamic> json) =>
      MigrationResult(
        eggs: _parse(json['eggs']),
        monsters: _parse(json['monsters']),
      );
}

/// 6단계 Phase 4 — 게스트 → 회원가입 마이그레이션 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
/// 아직 서버로 이관되지 않은(synced_at IS NULL) 로컬 user_eggs/user_monsters를 `POST /api/eggs/migrate`로
/// 보내고, 서버가 각 항목을 개별 판정한다(위조/불일치 항목은 거부, 나머지는 정상 반영). 로컬 SQLite는
/// 지우지 않음 — 화면이 여전히 로컬을 읽으므로, 여기서 지우면 로그인 직후 보관함/도감이 텅 비어 보임.
class MigrationApi {
  const MigrationApi(this._client);

  final AuthorizedApiClient _client;

  Future<MigrationResult> migrate({
    required List<UserEgg> eggs,
    required List<UserMonster> monsters,
  }) async {
    final res = await _client.post(
      '/api/eggs/migrate',
      body: {
        'eggs': eggs
            .map(
              (e) => {
                'id': e.id,
                'eggTypeId': e.eggTypeId,
                'rarity': e.rarity,
                'targetDistanceMeters': e.targetDistanceMeters,
                'distanceAccumulatedMeters': e.distanceAccumulatedMeters,
                // isPartner는 서버에 없는 개념 — 파트너는 순수 기기 로컬 상태(Document/temp.md Part 1).
                'tourismSpotId': e.tourismSpotId,
                'acquiredAt': e.acquiredAt.toIso8601String(),
                'hatchedAt': e.hatchedAt?.toIso8601String(),
              },
            )
            .toList(),
        'monsters': monsters
            .map(
              (m) => {
                'id': m.id,
                'monsterSpeciesId': m.monsterSpeciesId,
                'eggId': m.eggId,
                'tourismSpotId': m.tourismSpotId,
                'hatchedAt': m.hatchedAt.toIso8601String(),
              },
            )
            .toList(),
      },
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Migration request failed: ${res.statusCode} ${utf8.decode(res.bodyBytes)}',
      );
    }
    return MigrationResult.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

/// 재실행 조건을 row 단위(user_eggs/user_monsters의 synced_at)로 판단 — 아직 이관 안 된 항목만
/// 매 로그인마다 재시도한다. 예전엔 app_settings의 `migration_completed_at` 전역 플래그 하나로
/// "1회만 실행"을 판단했는데, 그 플래그가 로그아웃 시 초기화되지 않아서 "로그인 → 로그아웃 →
/// 게스트로 알 획득 → 재로그인" 시 새 게스트 데이터가 영영 서버로 안 넘어가고 부화가 404로
/// 실패하는 버그가 있었음(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md). synced_at은
/// migrated/already_done 응답에서만 채워지고 rejected는 안 채워지므로, 앱이 중간에 죽어도 다음
/// 로그인에 자연히 재시도되는 예전 플래그의 장점은 그대로 유지된다.
class MigrationService {
  const MigrationService({
    this.eggRepository = const EggRepository(),
    this.monsterRepository = const MonsterRepository(),
  });

  final EggRepository eggRepository;
  final MonsterRepository monsterRepository;

  /// 미이관 항목이 없으면 아무것도 안 함(정상 재로그인의 흔한 경로). 실패(네트워크 등)해도 예외를
  /// 그대로 던짐 — 호출부가 로그인 자체는 막지 않도록 흡수하고, synced_at을 안 남겨서 다음 계정
  /// 버튼 진입 시 재시도되게 함.
  Future<void> migrateIfNeeded(AuthorizedApiClient client) async {
    final eggs = await eggRepository.getUnsyncedEggs();
    final monsters = await monsterRepository.getUnsynced();
    if (eggs.isEmpty && monsters.isEmpty) return;

    // 미동기화 몬스터가 참조하는 알이 이미 synced라 위 목록에 없으면, 서버 migrate 루프가 그
    // 몬스터의 알 등급을 확인할 수 없어(verifiedEggRarity는 같은 요청에 실린 알에서만 채워짐)
    // 무조건 거부함 — 예: 알을 로그인 때 이관하고, 로그아웃한 뒤 게스트로 그 알을 부화한 경우.
    // 참조된 알을 synced 여부와 무관하게 페이로드에 포함(서버는 already_done으로 무해 처리하고
    // 등급 확인용으로만 씀).
    final payloadEggIds = eggs.map((e) => e.id).toSet();
    final referencedEggIds = monsters
        .map((m) => m.eggId)
        .whereType<String>()
        .where((id) => !payloadEggIds.contains(id))
        .toSet();
    final eggsToSend = [
      ...eggs,
      if (referencedEggIds.isNotEmpty)
        ...await eggRepository.getByIds(referencedEggIds),
    ];

    final result = await MigrationApi(client)
        .migrate(eggs: eggsToSend, monsters: monsters);

    await eggRepository.markSynced(
      result.eggs.where((e) => e.isConfirmed).map((e) => e.id),
    );
    await monsterRepository.markSynced(
      result.monsters.where((m) => m.isConfirmed).map((m) => m.id),
    );

    // 유통기한(GameConfig.guestEggShelfLife)을 넘겨 서버 egg_vouchers가 이미 TTL로 지워진 알은
    // `rejected`로 오고, 로컬에 남겨둬도 영영 이관/서버부화가 안 되는 좀비가 됨(로그인 상태에선
    // 보관함의 "굳음" UI/치우기 버튼도 안 뜸). 만료가 확인된 것만 골라 로컬에서도 정리한다 —
    // 만료 전인데 rejected면(위조 의심/타 기기 선점 등) 그대로 두고 로그로만 남김.
    final rejectedEggIds = result.eggs
        .where((e) => !e.isConfirmed)
        .map((e) => e.id)
        .toSet();
    final sentEggById = {for (final e in eggsToSend) e.id: e};
    final expiredDeadEggIds = rejectedEggIds
        .where((id) => sentEggById[id]?.isGuestShelfLifeExpired ?? false)
        .toList();
    for (final id in expiredDeadEggIds) {
      await eggRepository.deleteEgg(id);
    }
    if (expiredDeadEggIds.isNotEmpty) {
      developer.log(
        '유통기한이 지나 서버 voucher가 사라진 알 ${expiredDeadEggIds.length}개 로컬 정리: '
        '${expiredDeadEggIds.join(', ')}',
        name: 'Migration',
      );
    }

    final expiredSet = expiredDeadEggIds.toSet();
    final rejected = [
      ...result.eggs
          .where((e) => !e.isConfirmed && !expiredSet.contains(e.id))
          .map((e) => 'egg ${e.id}'),
      ...result.monsters
          .where((m) => !m.isConfirmed)
          .map((m) => 'monster ${m.id}'),
    ];
    if (rejected.isNotEmpty) {
      developer.log(
        '마이그레이션 거부됨(로컬 유지, 다음 로그인 재시도): ${rejected.join(', ')}',
        name: 'Migration',
      );
    }

    // 서버가 알의 거리 누적치를 절대값으로 실제로 흡수하는 건 `migrated`(신규 insert)뿐 —
    // `already_done`은 기존 row를 건드리지 않고, `rejected`는 반영 자체가 없음. 그 절대값에는
    // 게스트로 쌓인 몫이 이미 포함돼 있으므로, 그와 겹치는 "서버로 아직 안 보낸 전역 델타"를
    // 여기서 0으로 리셋해 이중 계산을 막음(distance_tracker_service.dart 참고). 순수하게
    // already_done만 돌아온 재로그인(노이즈)에선 리셋하지 않아 정상 델타를 보존.
    // ⚠️ 알려진 한계: 이전 로그인에 이미 이관된(synced) 파트너 알이 그 뒤 게스트 기간에 계속
    // 거리를 쌓았다면, 그 몫은 전역 델타에만 있고 이번 migrate 대상이 아니라서 `migrated`가
    // 하나라도 있으면 이 리셋으로 같이 유실됨 — 게스트/회원을 오가며 같은 파트너 알을 계속 쓰는
    // 드문 경우에만 발생. 추후 델타를 per-egg로 바꾸거나 migrate 전에 flush하는 방식으로 개선.
    if (result.eggs.any((e) => e.status == 'migrated')) {
      await DistanceTrackerService.instance.resetPendingServerSyncDelta();
    }
  }
}

/// 6단계 Phase 5 — 알 보관함/도감 복구(restore, `Document/study_folder/6-5_... 참고`). 새 기기/
/// 재설치로 로컬이 비어있어도 서버에 남아있는 데이터를 되찾아옴. id 충돌 시 무시(ignore)하는
/// 병합이라 매번 다시 실행해도 멱등하고 비용도 로컬 쿼리 수준 — 받아온 row는 synced_at을 채워서
/// 곧이어(또는 다음) migrateIfNeeded가 서버로 되돌려보내지 않게 함(upsertFromServer 참고).
class RestoreService {
  const RestoreService({
    this.eggRepository = const EggRepository(),
    this.monsterRepository = const MonsterRepository(),
  });

  final EggRepository eggRepository;
  final MonsterRepository monsterRepository;

  Future<void> restore(AuthorizedApiClient client) async {
    final api = RestoreApi(client);
    final eggs = await api.fetchEggs();
    final monsters = await api.fetchDex();
    await eggRepository.upsertFromServer(eggs);
    await monsterRepository.upsertFromServer(monsters);
  }
}

/// 로그인 성공(신규/재로그인) 직후 공용 후처리 — `AccountButton`(지도 화면 진입점)과
/// `MyPageScreen`(마이페이지에서 재로그인하는 경우) 둘 다 재사용. 실패해도(네트워크 등) 로그인
/// 자체는 막지 않도록 예외를 흡수하고 로그만 남김 — 마이그레이션은 미이관(synced_at IS NULL)
/// 항목이 남아있는 한 다음 진입 시 자연히 재시도되고, 복구는 멱등이라 매번 다시 시도해도 안전함.
Future<void> syncGuestDataWithServer(
  AuthorizedApiClient client, {
  MigrationService migrationService = const MigrationService(),
  RestoreService restoreService = const RestoreService(),
}) async {
  try {
    await migrationService.migrateIfNeeded(client);
  } catch (e) {
    developer.log('게스트→회원 마이그레이션 실패: $e', name: 'AuthSync');
  }
  try {
    await restoreService.restore(client);
  } catch (e) {
    developer.log('서버 데이터 복구 실패: $e', name: 'AuthSync');
  }
}
