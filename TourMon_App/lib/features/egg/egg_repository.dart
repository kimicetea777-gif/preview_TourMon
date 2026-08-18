import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../config/game_config.dart';
import '../../data/app_database.dart';
import '../../data/day_key.dart';
import 'user_egg.dart';

/// 3~4단계 — 알 로컬 저장/쿨타임 체크/보관함/파트너/부화 진행도. 게스트 모드는 서버에 상태가 없어서
/// "스팟당 하루 1회" 쿨타임, "파트너 최대 2개" 같은 검증도 여기(클라이언트)에서만 판정함
/// (egg_api.dart 상단 주석 참고, 회원 전환 시 6단계에서 서버 쪽 검증이 추가될 자리).
class EggRepository {
  const EggRepository();

  static const _uuid = Uuid();

  /// "오늘" 이 스팟에서 이미 알을 받았는지 — 자정이 아니라 KST 새벽 4시(GameConfig.dailyResetHourKst)
  /// 경계로 판정. 로그인 상태에서 서버(TourMon/src/lib/game-config.ts DAILY_RESET_HOUR_KST)가
  /// 같은 기준으로 최종 판정하므로, 여기가 자정 기준이면 밤 11시~새벽 1시 사이에 클라이언트/서버
  /// 판정이 어긋남(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md). 스팟당 하루 최대 1건이라 가장 최근 획득 1건만 보면 충분.
  Future<bool> hasAcquiredToday(int tourismSpotId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      columns: ['acquired_at'],
      where: 'tourism_spot_id = ?',
      whereArgs: [tourismSpotId],
      orderBy: 'acquired_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final lastAcquiredAt = DateTime.parse(rows.first['acquired_at'] as String);
    return resetDayKey(lastAcquiredAt) == resetDayKey(DateTime.now());
  }

  /// 마커 쿨타임 배지(Document/temp.md "마커 쿨타임 배지") 배치 조회 — 오늘 이미 획득한 스팟 id
  /// 전체를 한 번에 Set으로 가져옴. `hasAcquiredToday`처럼 스팟 하나당 쿼리 하나씩 부르면 화면에
  /// 뜬 마커 전체(N개)만큼 비동기 쿼리가 나가버리므로, 대신 여기서 하루치 후보만 넓게 가져온 뒤
  /// Dart에서 resetDayKey로 걸러서 반환 — 마커 빌드 시엔 이 Set에 `.contains()`만 동기적으로 체크.
  Future<Set<int>> getAcquiredTodaySpotIds() async {
    final db = await AppDatabase.instance.database;
    // KST 4시 경계 때문에 "오늘"이 캘린더 자정 이전부터 시작할 수 있어, 넉넉히 지난 24시간 +
    // 리셋 시각만큼 더 앞선 시점부터 후보를 가져와서 resetDayKey로 최종 판정.
    final since = DateTime.now().subtract(
      Duration(hours: 24 + GameConfig.dailyResetHourKst),
    );
    final rows = await db.query(
      'user_eggs',
      columns: ['tourism_spot_id', 'acquired_at'],
      where: 'tourism_spot_id IS NOT NULL AND acquired_at >= ?',
      whereArgs: [since.toIso8601String()],
    );
    final todayKey = resetDayKey(DateTime.now());
    final ids = <int>{};
    for (final row in rows) {
      final acquiredAt = DateTime.parse(row['acquired_at'] as String);
      if (resetDayKey(acquiredAt) == todayKey) {
        ids.add(row['tourism_spot_id'] as int);
      }
    }
    return ids;
  }

  /// [overrideId]가 있으면 그 값을 로컬 id로 씀(서버가 acquire 응답으로 내려준 egg_vouchers.id —
  /// 마이그레이션 시 위조 검증 대조 키로 쓰이므로 게스트/로그인 구분 없이 항상 서버 값을 그대로
  /// 써야 함, Document/study_folder/6-4_게스트 회원가입 마이그레이션.md). 없으면(예: 미래에 서버 없이 로컬만 쓰는 경로가 생기면)
  /// 기존처럼 자체 생성 — acquire 경로는 이제 항상 값을 주므로 사실상 fallback용.
  Future<UserEgg> insertEgg({
    required int tourismSpotId,
    required String? tourismSpotTitle,
    required int contentTypeId,
    required int eggTypeId,
    required String rarity,
    required String name,
    required String? description,
    required int targetSteps,
    String? overrideId,
  }) async {
    final egg = UserEgg(
      id: overrideId ?? _uuid.v7(),
      tourismSpotId: tourismSpotId,
      tourismSpotTitle: tourismSpotTitle,
      contentTypeId: contentTypeId,
      eggTypeId: eggTypeId,
      rarity: rarity,
      name: name,
      description: description,
      targetSteps: targetSteps,
      stepsAccumulated: 0,
      isPartner: false,
      acquiredAt: DateTime.now(),
      hatchedAt: null,
    );
    final db = await AppDatabase.instance.database;
    await db.insert('user_eggs', egg.toMap());
    return egg;
  }

  /// 6단계 Phase 5 — 서버 복구(restore, `GET /api/eggs`)로 받은 알들을 로컬에 병합. id가 이미
  /// 로컬에 있으면 그대로 무시(ConflictAlgorithm.ignore) — 새 기기/재설치처럼 로컬이 비어있을 때만
  /// 실제로 채워지고, 이미 최신 로컬 데이터가 있으면 서버의(최대 몇 분 지연될 수 있는) 스냅샷으로
  /// 덮어쓰지 않음(Document/study_folder/6-5_... 참고).
  Future<void> upsertFromServer(List<UserEgg> eggs) async {
    if (eggs.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final egg in eggs) {
      batch.insert('user_eggs', egg.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// 마이그레이션(migration_service.dart의 MigrationApi가 사용)용 — 부화 여부 무관 전체 알.
  /// voucher는 부화 여부와 무관하게 획득 시점에만 생성/소비되므로 hatched 알도 포함해서 보내야 함
  /// (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
  Future<List<UserEgg>> getAllEggs() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('user_eggs', orderBy: 'acquired_at ASC');
    return rows.map(UserEgg.fromMap).toList();
  }

  /// 보관함 조회 — 아직 부화 안 한 모든 알(파트너 아닌 것 포함), 획득순.
  Future<List<UserEgg>> getUnhatchedEggs() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      where: 'hatched_at IS NULL',
      orderBy: 'acquired_at ASC',
    );
    return rows.map(UserEgg.fromMap).toList();
  }

  Future<int> countPartners() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM user_eggs WHERE is_partner = 1 AND hatched_at IS NULL",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// 파트너 지정/해제. 지정 시 최대 [GameConfig.maxPartnerEggs] 초과하면 거부.
  /// 해제해도 steps_accumulated는 유지(일시정지 개념) — init_plan.md 4-3 섹션.
  Future<bool> setPartner(String eggId, bool isPartner) async {
    if (isPartner) {
      final current = await countPartners();
      if (current >= GameConfig.maxPartnerEggs) return false;
    }
    final db = await AppDatabase.instance.database;
    await db.update(
      'user_eggs',
      {'is_partner': isPartner ? 1 : 0},
      where: 'id = ?',
      whereArgs: [eggId],
    );
    return true;
  }

  /// 걸음수 델타를 활성 파트너 알 전체에 각각 그대로 적립(4-3 섹션: "나눠 갖지 않음").
  /// 갱신 후 상태를 반환 — 방금 부화 목표에 도달한 알을 호출부에서 감지하는 데 사용.
  Future<List<UserEgg>> _getPartnerEggs(Database db) async {
    final rows = await db.query(
      'user_eggs',
      where: 'is_partner = 1 AND hatched_at IS NULL',
    );
    return rows.map(UserEgg.fromMap).toList();
  }

  Future<List<UserEgg>> addStepsToPartners(int deltaSteps) async {
    final db = await AppDatabase.instance.database;
    if (deltaSteps <= 0) return _getPartnerEggs(db);
    await db.rawUpdate(
      '''
      UPDATE user_eggs
      SET steps_accumulated = steps_accumulated + ?
      WHERE is_partner = 1 AND hatched_at IS NULL
      ''',
      [deltaSteps],
    );
    return _getPartnerEggs(db);
  }

  /// [executor]를 주면 그 트랜잭션 안에서 실행 — 부화 시 monster_repository.insertHatchedMonster와
  /// 하나의 트랜잭션으로 묶어서 원자적으로 처리하는 데 사용(EggInventoryScreen._onHatchPressed 참고).
  /// 안 주면 기본 DB에 바로 씀(기존 호출부 호환).
  Future<void> markHatched(String eggId, DateTime hatchedAt, {DatabaseExecutor? executor}) async {
    final db = executor ?? await AppDatabase.instance.database;
    await db.update(
      'user_eggs',
      {'hatched_at': hatchedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [eggId],
    );
  }
}
