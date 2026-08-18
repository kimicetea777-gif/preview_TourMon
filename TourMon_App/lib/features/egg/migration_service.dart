import 'dart:convert';
import 'dart:developer' as developer;

import '../../data/app_settings_repository.dart';
import '../auth/authorized_api_client.dart';
import '../monster/monster_repository.dart';
import '../monster/user_monster.dart';
import '../steps/step_tracker_service.dart';
import 'egg_repository.dart';
import 'restore_api.dart';
import 'user_egg.dart';

/// 6단계 Phase 4 — 게스트 → 회원가입 마이그레이션 (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
/// 로컬 SQLite user_eggs/user_monsters 전체를 `POST /api/eggs/migrate`로 보내고, 서버가 각 항목을
/// 개별 판정한다(위조/불일치 항목은 거부, 나머지는 정상 반영). 로컬 SQLite는 지우지 않음 — 다음
/// Phase(서버 동기화 조회 API)가 붙기 전까지는 화면이 여전히 로컬만 읽으므로, 여기서 지우면 로그인
/// 직후 보관함/도감이 텅 비어 보이는 회귀가 생김.
class MigrationApi {
  const MigrationApi(this._client);

  final AuthorizedApiClient _client;

  Future<void> migrate({
    required List<UserEgg> eggs,
    required List<UserMonster> monsters,
  }) async {
    final res = await _client.post(
      '/api/eggs/migrate',
      body: {
        'eggs': eggs
            .map((e) => {
                  'id': e.id,
                  'eggTypeId': e.eggTypeId,
                  'rarity': e.rarity,
                  'targetSteps': e.targetSteps,
                  'stepsAccumulated': e.stepsAccumulated,
                  'isPartner': e.isPartner,
                  'tourismSpotId': e.tourismSpotId,
                  'acquiredAt': e.acquiredAt.toIso8601String(),
                  'hatchedAt': e.hatchedAt?.toIso8601String(),
                })
            .toList(),
        'monsters': monsters
            .map((m) => {
                  'id': m.id,
                  'monsterSpeciesId': m.monsterSpeciesId,
                  'eggId': m.eggId,
                  'tourismSpotId': m.tourismSpotId,
                  'hatchedAt': m.hatchedAt.toIso8601String(),
                })
            .toList(),
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Migration request failed: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
  }
}

/// 로그인+온보딩 직후 1회만 트리거되도록 `migration_completed_at` 플래그로 재시도 여부를 판단.
/// 로그인 성공 여부가 아니라 플래그 유무로 판단해야, 마이그레이션이 성공했지만 플래그 기록 직전에
/// 앱이 죽은 예외 케이스도 다음 로그인 때 자연히 재시도됨(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
class MigrationService {
  const MigrationService({
    this.eggRepository = const EggRepository(),
    this.monsterRepository = const MonsterRepository(),
    this.settings = const AppSettingsRepository(),
  });

  static const _migrationCompletedAtKey = 'migration_completed_at';

  final EggRepository eggRepository;
  final MonsterRepository monsterRepository;
  final AppSettingsRepository settings;

  Future<bool> get hasMigrated async =>
      (await settings.getValue(_migrationCompletedAtKey)) != null;

  /// 이미 완료됐으면 아무것도 안 함. 실패(네트워크 등)해도 예외를 그대로 던짐 — 호출부가 로그인
  /// 자체는 막지 않도록 흡수하고, 플래그를 안 남겨서 다음 계정 버튼 진입 시 재시도되게 함.
  Future<void> migrateIfNeeded(AuthorizedApiClient client) async {
    if (await hasMigrated) return;

    final eggs = await eggRepository.getAllEggs();
    final monsters = await monsterRepository.getAll();
    if (eggs.isNotEmpty || monsters.isNotEmpty) {
      await MigrationApi(client).migrate(eggs: eggs, monsters: monsters);
    }
    await settings.setValue(_migrationCompletedAtKey, DateTime.now().toIso8601String());
    // migrate가 로컬의 현재 걸음수 누적치를 절대값으로 서버에 실어보냈으므로, 그 이전에 쌓여있던
    // "서버로 아직 안 보낸 델타"를 또 더하면 이중 계산됨 — 여기서 0으로 리셋(step_tracker_service.dart
    // 참고).
    await StepTrackerService.instance.resetPendingServerSyncDelta();
  }
}

/// 6단계 Phase 5 — 알 보관함/도감 복구(restore, `Document/study_folder/6-5_... 참고`). 새 기기/
/// 재설치로 로컬이 비어있어도 서버에 남아있는 데이터를 되찾아옴. 마이그레이션과 달리 완료 플래그가
/// 없음 — id 충돌 시 무시(ignore)하는 병합이라 매번 다시 실행해도 멱등하고 비용도 로컬 쿼리 수준.
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
/// 자체는 막지 않도록 예외를 흡수하고 로그만 남김 — 마이그레이션은 `migration_completed_at`
/// 플래그가 없는 한 다음 진입 시 자연히 재시도되고, 복구는 멱등이라 매번 다시 시도해도 안전함.
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
