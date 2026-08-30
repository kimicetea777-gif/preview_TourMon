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
  ///
  /// [syncedAt]을 주면(로그인 상태 획득 — acquire 라우트가 같은 id로 서버 user_eggs row도 이미
  /// 생성함) 로컬 row에 이관 완료 시각을 박아 다음 로그인의 마이그레이션 대상에서 뺌. 안 주면
  /// (게스트 획득) NULL로 남아 마이그레이션 대상이 됨.
  Future<UserEgg> insertEgg({
    required int tourismSpotId,
    required String? tourismSpotTitle,
    required int contentTypeId,
    required int eggTypeId,
    required String rarity,
    required String name,
    required String? description,
    required int targetDistanceMeters,
    String? overrideId,
    DateTime? syncedAt,
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
      targetDistanceMeters: targetDistanceMeters,
      distanceAccumulatedMeters: 0,
      isPartner: false,
      acquiredAt: DateTime.now(),
      hatchedAt: null,
    );
    final db = await AppDatabase.instance.database;
    await db.insert('user_eggs', {
      ...egg.toMap(),
      if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
    });
    return egg;
  }

  /// 6단계 Phase 5 — 서버 복구(restore, `GET /api/eggs`)로 받은 알들을 로컬에 병합. id가 이미
  /// 로컬에 있으면 그대로 무시(ConflictAlgorithm.ignore) — 새 기기/재설치처럼 로컬이 비어있을 때만
  /// 실제로 채워지고, 이미 최신 로컬 데이터가 있으면 서버의(최대 몇 분 지연될 수 있는) 스냅샷으로
  /// 덮어쓰지 않음(Document/study_folder/6-5_... 참고).
  Future<void> upsertFromServer(List<UserEgg> eggs) async {
    if (eggs.isEmpty) return;
    final db = await AppDatabase.instance.database;
    // 서버에서 받아온 알이므로 이미 서버에 존재함 — synced_at을 채워서 다음 로그인 때
    // migrateIfNeeded가 이 알들을 다시 밀어올리지 않게 함(밀어올려도 already_done으로
    // 무해하지만, 재설치 복구 직후 첫 로그인의 불필요한 대량 재전송을 피함).
    final syncedAt = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final egg in eggs) {
      batch.insert('user_eggs', {
        ...egg.toMap(),
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Part 3-B(Document/temp.md) — 이미 로컬에 있어 insert가 ignore된 알도 부화 판정 기준값
      // (서버 PG)에 수렴시킴. 회원은 distance_accumulated_meters가 서버 authoritative: 로컬이
      // 속도 클램프/유실/mock 감지로 서버보다 앞서 있으면 "부화 준비 완료"를 보고 눌렀다가
      // 서버 부화에서 422를 맞는 불일치가 생김(재로그인/새 기기 시점 정합). 방금 insert된 알은
      // 이미 같은 값이라 이 update가 무해(멱등). is_partner 등 다른 로컬 필드는 안 건드림.
      batch.update(
        'user_eggs',
        {'distance_accumulated_meters': egg.distanceAccumulatedMeters},
        where: 'id = ?',
        whereArgs: [egg.id],
      );
    }
    await batch.commit(noResult: true);
    // 이미 로컬에 있던(그래서 ignore된) 알도 서버 존재가 확인된 것이므로 synced_at을 채움.
    await markSynced(eggs.map((e) => e.id));
  }

  /// Part 1(Document/temp.md) — `POST /api/distance/sync`에 실어보낼 "이번에 거리를 적립할 알"
  /// id 목록. 서버엔 파트너 개념이 없어(파트너 = 순수 기기 로컬) 클라가 매 sync마다 현재 파트너
  /// 알 id를 직접 넘긴다. 로컬 `addDistanceToPartners()`와 동일한 필터(is_partner=1, 미부화).
  Future<List<String>> getPartnerEggIds() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      columns: ['id'],
      where: 'is_partner = 1 AND hatched_at IS NULL',
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Part 3-A(Document/temp.md) — `POST /api/distance/sync` 응답으로 받은 서버 누적 거리를 파트너
  /// 알 로컬 값에 그대로 덮어씀(max 아님, 서버 우선). 서버가 속도 클램프로 초과분을 잘라냈거나
  /// mock 감지로 적립을 스킵한 경우, 로컬이 서버보다 앞서 "부화 준비 완료"를 표시했다가 서버
  /// 부화에서 422를 맞는 불일치를 없앤다. 회원 경로에서 로컬 적립은 "낙관적 표시, 다음 sync에
  /// 보정"이 됨(게스트는 서버 사본이 없어 무관 — 애초에 호출되지 않음).
  Future<void> applyServerDistances(Map<String, int> distanceById) async {
    if (distanceById.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    distanceById.forEach((id, meters) {
      batch.update(
        'user_eggs',
        {'distance_accumulated_meters': meters},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await batch.commit(noResult: true);
  }

  /// 마이그레이션(migration_service.dart)용 — 아직 서버로 이관되지 않은(synced_at IS NULL) 알만.
  /// 부화 여부와 무관하게 포함: voucher는 부화 여부와 상관없이 획득 시점에만 생성/소비되므로
  /// hatched 알도 이관해야 서버가 voucher를 소진하고 부화한 몬스터도 넘길 수 있음
  /// (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
  Future<List<UserEgg>> getUnsyncedEggs() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      where: 'synced_at IS NULL',
      orderBy: 'acquired_at ASC',
    );
    return rows.map(UserEgg.fromMap).toList();
  }

  /// 단건 재조회 — 부화 직전 재이관을 시도한 뒤 그 알의 synced_at이 실제로 채워졌는지(또는
  /// 만료로 삭제됐는지) 다시 확인하는 데 씀(egg_inventory_screen.dart `_determineSpecies`).
  Future<UserEgg?> getById(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserEgg.fromMap(rows.first);
  }

  /// 마이그레이션용 — 미동기화 몬스터가 참조하는 알을 synced 여부와 무관하게 같이 실어보내기
  /// 위한 조회(migration_service.dart 주석 참고). 서버 migrate 루프는 verifiedEggRarity를 그
  /// 요청에 실린 알에서만 채우므로, 알이 먼저 이관돼 목록에서 빠지면 그 알의 몬스터가 영구 거부됨.
  Future<List<UserEgg>> getByIds(Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return [];
    final db = await AppDatabase.instance.database;
    final result = <UserEgg>[];
    for (var i = 0; i < idList.length; i += 500) {
      final chunk = idList.sublist(
        i,
        i + 500 > idList.length ? idList.length : i + 500,
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.query(
        'user_eggs',
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      result.addAll(rows.map(UserEgg.fromMap));
    }
    return result;
  }

  /// 서버 반영이 확인된(migrated/already_done, 또는 복구로 받아온) 알들을 이관 완료로 표시.
  /// [executor]를 주면 부화 트랜잭션 안에서 같이 커밋(로그인 상태 부화 시 사용). id 개수가
  /// SQLite 변수 한도(구버전 999)를 넘을 수 있어 청크로 나눠 실행.
  Future<void> markSynced(
    Iterable<String> ids, {
    DatabaseExecutor? executor,
  }) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final db = executor ?? await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < idList.length; i += 500) {
      final chunk = idList.sublist(
        i,
        i + 500 > idList.length ? idList.length : i + 500,
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await db.rawUpdate(
        'UPDATE user_eggs SET synced_at = ? WHERE id IN ($placeholders)',
        [now, ...chunk],
      );
    }
  }

  /// 보관함 조회 — 아직 부화 안 한 모든 알(파트너 아닌 것 포함). 파트너로 지정된 알을 최상단으로
  /// 올리고(is_partner DESC), 그 안에서는 획득순(acquired_at ASC). partner_egg_progress_box는
  /// 어차피 파트너 알만 골라 쓰므로 이 정렬 변경의 영향을 안 받음.
  Future<List<UserEgg>> getUnhatchedEggs() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'user_eggs',
      where: 'hatched_at IS NULL',
      orderBy: 'is_partner DESC, acquired_at ASC',
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

  /// 거리 델타를 활성 파트너 알 전체에 각각 그대로 적립(4-3 섹션: "나눠 갖지 않음").
  /// 갱신 후 상태를 반환 — 방금 부화 목표에 도달한 알을 호출부에서 감지하는 데 사용.
  Future<List<UserEgg>> _getPartnerEggs(Database db) async {
    final rows = await db.query(
      'user_eggs',
      where: 'is_partner = 1 AND hatched_at IS NULL',
    );
    return rows.map(UserEgg.fromMap).toList();
  }

  Future<List<UserEgg>> addDistanceToPartners(int deltaMeters) async {
    final db = await AppDatabase.instance.database;
    if (deltaMeters <= 0) return _getPartnerEggs(db);
    await db.rawUpdate(
      '''
      UPDATE user_eggs
      SET distance_accumulated_meters = distance_accumulated_meters + ?
      WHERE is_partner = 1 AND hatched_at IS NULL
      ''',
      [deltaMeters],
    );
    return _getPartnerEggs(db);
  }

  /// [executor]를 주면 그 트랜잭션 안에서 실행 — 부화 시 monster_repository.insertHatchedMonster와
  /// 하나의 트랜잭션으로 묶어서 원자적으로 처리하는 데 사용(EggInventoryScreen._onHatchPressed 참고).
  /// 안 주면 기본 DB에 바로 씀(기존 호출부 호환).
  Future<void> markHatched(
    String eggId,
    DateTime hatchedAt, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await AppDatabase.instance.database;
    await db.update(
      'user_eggs',
      {'hatched_at': hatchedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [eggId],
    );
  }

  /// 유통기한이 지나 "굳어버린" 게스트 알을 보관함에서 제거(init_plan.md "클라이언트 측 선제 체크").
  /// 서버 강제력은 여전히 egg_vouchers 삭제에 있고, 이건 실패 시점을 회원가입이 아니라 부화 시점의
  /// 게임 내 이벤트로 앞당기는 UX 장치라 로컬 row만 지우면 됨.
  Future<void> deleteEgg(String eggId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('user_eggs', where: 'id = ?', whereArgs: [eggId]);
  }
}
