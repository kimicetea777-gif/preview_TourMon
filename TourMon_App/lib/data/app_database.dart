import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 게스트 모드 로컬 저장소 — 서버 `user_eggs`/`user_monsters` 스키마와 최대한 대응
/// (init_plan.md DB 스키마 참고). 로그인(6단계) 시 이 row들을 서버로 마이그레이션할 예정이라
/// 컬럼을 최대한 맞춰둠.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbVersion = 7;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'tourmon.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_eggs (
            id TEXT PRIMARY KEY,
            tourism_spot_id INTEGER,
            content_type_id INTEGER,
            egg_type_id INTEGER NOT NULL,
            rarity TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            target_distance_meters INTEGER NOT NULL,
            distance_accumulated_meters INTEGER NOT NULL DEFAULT 0,
            is_partner INTEGER NOT NULL DEFAULT 0,
            acquired_at TEXT NOT NULL,
            hatched_at TEXT
          )
        ''');
        await db.execute(_createUserMonstersSql);
        await db.execute(_createAppSettingsSql);
        await _addTourismSpotTitleColumns(db);
        await _addSyncedAtColumns(db);
        await _createTourismSpotsCacheTable(db);
        await _createDailyDistanceTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE user_eggs ADD COLUMN content_type_id INTEGER');
          await db.execute(_createUserMonstersSql);
          await db.execute(_createAppSettingsSql);
        }
        if (oldVersion < 3) {
          await _addTourismSpotTitleColumns(db);
        }
        if (oldVersion < 4) {
          await _createTourismSpotsCacheTable(db);
        }
        // v5 신설 테이블(daily_steps)은 v6에서 daily_distance로 바로 대체되므로 여기서 따로
        // 만들지 않음(아래 oldVersion < 6 분기가 처리).
        if (oldVersion < 6) {
          // Health Connect 전환(Document/temp.md "통합 결정") — 걸음수 → 거리(meters). 실사용자
          // 없음이 확인된 전제(temp.md 미결 사항)라 컬럼값 변환 없이 이름만 맞춰 새로 시작.
          await db.execute(
            'ALTER TABLE user_eggs RENAME COLUMN target_steps TO target_distance_meters',
          );
          await db.execute(
            'ALTER TABLE user_eggs RENAME COLUMN steps_accumulated TO distance_accumulated_meters',
          );
          // daily_steps는 순수 표시용 캐시라 데이터 보존 없이 새 테이블로 교체(기존 "그냥 초기화"
          // 결정과 같은 결, temp.md 미결 사항 참고).
          await db.execute('DROP TABLE IF EXISTS daily_steps');
          await _createDailyDistanceTable(db);
        }
        if (oldVersion < 7) {
          // 게스트→회원 마이그레이션 재실행 조건을 전역 1회성 플래그(app_settings의
          // `migration_completed_at`)에서 row 단위 추적으로 교체 — 자세한 배경은
          // `_addSyncedAtColumns` 참고.
          await _addSyncedAtColumns(db);
          // 더 이상 안 읽는 죽은 키 — 남아 있으면 DB를 직접 들여다볼 때 혼란만 줌.
          await db.delete(
            'app_settings',
            where: 'key = ?',
            whereArgs: ['migration_completed_at'],
          );
        }
      },
    );
  }

  /// v3에서 추가 — 알 획득/부화 시점에 이미 들고 있는 관광지 이름을 스냅샷으로 저장해서, 도감
  /// 상세화면에서 관광지 이름 조회 API 없이도 획득 장소를 표시할 수 있게 함(5단계 후속 개선).
  /// onCreate/onUpgrade 양쪽에서 공유 — 두 곳 모두 CREATE TABLE 시점엔 이 컬럼 없이 만들고
  /// 여기서 ALTER로 추가하므로, 중복 컬럼 에러 없이 항상 같은 경로를 탄다.
  Future<void> _addTourismSpotTitleColumns(Database db) async {
    await db.execute('ALTER TABLE user_eggs ADD COLUMN tourism_spot_title TEXT');
    await db.execute('ALTER TABLE user_monsters ADD COLUMN tourism_spot_title TEXT');
  }

  /// v7에서 추가 — 게스트→회원 마이그레이션이 이 row를 서버로 이관 완료했는지 추적. NULL이면
  /// 아직 미이관(다음 로그인에 재시도), 값이 있으면 서버 반영이 확인된 시각(ISO8601). 예전엔
  /// app_settings의 `migration_completed_at` 전역 플래그 하나로 "1회만 실행"을 판단했는데, 그
  /// 플래그가 로그아웃 시 초기화되지 않아서 "로그인 → 로그아웃 → 게스트로 알 획득 → 재로그인"
  /// 시 새 게스트 데이터가 영영 서버로 안 넘어가고 부화가 404로 실패하는 버그가 있었음
  /// (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md). `_addTourismSpotTitleColumns`와
  /// 같은 이유로 CREATE 문에 넣지 않고 항상 ALTER로 추가 — v1에서 올라오는 기기가 oldVersion<2
  /// 분기에서 user_monsters를 새로 만드는 경로와 컬럼이 중복되지 않게.
  Future<void> _addSyncedAtColumns(Database db) async {
    await db.execute('ALTER TABLE user_eggs ADD COLUMN synced_at TEXT');
    await db.execute('ALTER TABLE user_monsters ADD COLUMN synced_at TEXT');
  }

  /// v4 — 관광지 로컬 캐싱(Document/temp.md "tour_spot 로컬 캐싱"). `user_eggs`/`user_monsters`와
  /// 달리 유저 소유 데이터가 아니라 공용 참조 캐시라 게스트/로그인과 무관하게 항상 존재. 델타 없이
  /// 전체 재다운로드 후 통째 교체 방식이라(TourismSpotRepository.syncBulk) 별도 갱신 시각 컬럼은
  /// 두지 않고, 마지막 동기화 시각은 app_settings에 key-value로 저장.
  Future<void> _createTourismSpotsCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tourism_spots (
        id INTEGER PRIMARY KEY,
        content_id TEXT NOT NULL,
        title TEXT NOT NULL,
        title_en TEXT,
        addr1 TEXT,
        addr2 TEXT,
        first_image TEXT,
        content_type_id INTEGER NOT NULL,
        cpyrht_div_cd TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        representative_spot_id INTEGER NOT NULL,
        is_representative INTEGER NOT NULL,
        member_count INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tourism_spots_is_representative '
      'ON tourism_spots(is_representative)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tourism_spots_representative_spot_id '
      'ON tourism_spots(representative_spot_id)',
    );
  }

  /// v5(원래 daily_steps) → v6(Health Connect 전환, Document/temp.md "통합 결정")에서 daily_distance로
  /// 교체 — 거리 일별 히스토리(Document/plan/later.md "마이페이지 — 걸음수 통계"). 지도 화면 파트너
  /// 알 박스의 "오늘 거리" 표시용. `date`는 KST 4시 경계 기준 날짜 키(day_key.dart `resetDayKey`와
  /// 동일 형식, YYYY-MM-DD). `distance_meters`는 Health Connect 구간을 `splitByResetDay`로 날짜별
  /// 비례 배분한 값이라 REAL(소수 가능).
  Future<void> _createDailyDistanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_distance (
        date TEXT PRIMARY KEY,
        distance_meters REAL NOT NULL DEFAULT 0
      )
    ''');
  }

  static const _createUserMonstersSql = '''
    CREATE TABLE IF NOT EXISTS user_monsters (
      id TEXT PRIMARY KEY,
      monster_species_id INTEGER NOT NULL,
      egg_id TEXT,
      tourism_spot_id INTEGER,
      attribute TEXT NOT NULL,
      rarity TEXT NOT NULL,
      dex_number INTEGER NOT NULL,
      image_url TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      hatched_at TEXT NOT NULL
    )
  ''';

  // 거리 동기화 기준 시각(distance_last_synced_at) 등 단순 key-value 설정 저장용 — 4단계에서 처음 도입.
  static const _createAppSettingsSql = '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';
}
