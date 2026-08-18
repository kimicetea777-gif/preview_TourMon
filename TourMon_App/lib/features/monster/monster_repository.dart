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
  Future<UserMonster> insertHatchedMonster({
    required MonsterSpecies species,
    required String? eggId,
    required int? tourismSpotId,
    required String? tourismSpotTitle,
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
    await db.insert('user_monsters', monster.toMap());
    return monster;
  }

  /// 6단계 Phase 5 — 서버 복구(restore, `GET /api/monsters/dex`)로 받은 몬스터들을 로컬에 병합.
  /// EggRepository.upsertFromServer와 동일한 이유로 id 충돌 시 무시(Document/study_folder/6-5_...
  /// 참고).
  Future<void> upsertFromServer(List<UserMonster> monsters) async {
    if (monsters.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final monster in monsters) {
      batch.insert('user_monsters', monster.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
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
