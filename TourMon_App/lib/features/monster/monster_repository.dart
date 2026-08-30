import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_database.dart';
import 'monster_species.dart';
import 'user_monster.dart';

/// 부화 완료된 몬스터 로컬 저장/조회 — 도감 목록/상세 화면(5단계)은 `dex_screen.dart` 참고.
class MonsterRepository {
  const MonsterRepository();

  static const _uuid = Uuid();

  /// [executor]를 주면 그 트랜잭션 안에서 실행 — egg_repository.markHatched와 하나의 트랜잭션으로
  /// 묶어서 "몬스터는 생겼는데 알은 안 없어짐" 같은 불일치를 방지(init_plan.md 4-3 섹션의 원자성
  /// 원칙을 게스트 로컬 저장에도 동일 적용, EggInventoryScreen._onHatchPressed 참고).
  /// [syncedAt]을 주면(로그인 상태 부화 — 서버가 이미 authoritative하게 몬스터를 생성함) 로컬
  /// row에 이관 완료 시각을 같이 박아둠. 안 주면(게스트 부화) synced_at은 NULL로 남아 다음
  /// 로그인 때 마이그레이션 대상이 됨. ⚠️ 로그인 상태 부화에서 서버가 만든 몬스터 id와 이
  /// 로컬 id는 서로 다름(hatch/route.ts가 자체 uuidv7 생성) — 그래서 synced_at을 안 박으면
  /// 이 로컬 몬스터가 매 로그인마다 마이그레이션으로 전송됐다가 egg_id unique 충돌로 거부되는
  /// 노이즈가 생김.
  Future<UserMonster> insertHatchedMonster({
    required MonsterSpecies species,
    required String? eggId,
    required int? tourismSpotId,
    required String? tourismSpotTitle,
    DateTime? syncedAt,
    DatabaseExecutor? executor,
  }) async {
    final monster = UserMonster(
      id: _uuid.v7(),
      monsterSpeciesId: species.id,
      eggId: eggId,
      tourismSpotId: tourismSpotId,
      tourismSpotTitle: tourismSpotTitle,
      attribute: species.attribute,
      rarity: species.rarity,
      dexNumber: species.dexNumber,
      imageUrl: species.imageUrl,
      name: species.name,
      description: species.description,
      hatchedAt: DateTime.now(),
    );
    final db = executor ?? await AppDatabase.instance.database;
    await db.insert('user_monsters', {
      ...monster.toMap(),
      if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
    });
    return monster;
  }

  /// 6단계 Phase 5 — 서버 복구(restore, `GET /api/monsters/dex`)로 받은 몬스터들을 로컬에 병합.
  /// EggRepository.upsertFromServer와 동일한 이유로 id 충돌 시 무시(Document/study_folder/6-5_...
  /// 참고).
  Future<void> upsertFromServer(List<UserMonster> monsters) async {
    if (monsters.isEmpty) return;
    final db = await AppDatabase.instance.database;
    // EggRepository.upsertFromServer와 같은 이유 — 서버발이라 이미 이관된 것으로 표시.
    final syncedAt = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final monster in monsters) {
      batch.insert(
        'user_monsters',
        {...monster.toMap(), 'synced_at': syncedAt},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    await markSynced(monsters.map((m) => m.id));
  }

  /// 마이그레이션(migration_service.dart)용 — 아직 서버로 이관되지 않은(synced_at IS NULL) 몬스터만.
  Future<List<UserMonster>> getUnsynced() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_monsters',
      where: 'synced_at IS NULL',
      orderBy: 'hatched_at ASC',
    );
    return rows.map(UserMonster.fromMap).toList();
  }

  /// 서버 반영이 확인된(migrated/already_done, 또는 복구로 받아온) 몬스터들을 이관 완료로 표시.
  /// 도감 복구는 전체 몬스터를 돌려주므로 id 개수가 SQLite 변수 한도(구버전 999)를 넘을 수 있어
  /// 청크로 나눠 실행.
  Future<void> markSynced(Iterable<String> ids, {DatabaseExecutor? executor}) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final db = executor ?? await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < idList.length; i += 500) {
      final chunk = idList.sublist(i, i + 500 > idList.length ? idList.length : i + 500);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await db.rawUpdate(
        'UPDATE user_monsters SET synced_at = ? WHERE id IN ($placeholders)',
        [now, ...chunk],
      );
    }
  }

  Future<List<UserMonster>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('user_monsters', orderBy: 'hatched_at DESC');
    return rows.map(UserMonster.fromMap).toList();
  }

  /// 도감 목록 화면용 — 종(monster_species_id)별로 묶은 개체 목록(각 리스트는 부화일 최신순).
  /// 종 하나당 카드 하나 + 마릿수 배지로 보여주기 위해 사용(5단계).
  Future<Map<int, List<UserMonster>>> getGroupedBySpeciesId() async {
    final all = await getAll();
    final grouped = <int, List<UserMonster>>{};
    for (final monster in all) {
      grouped.putIfAbsent(monster.monsterSpeciesId, () => []).add(monster);
    }
    return grouped;
  }
}
