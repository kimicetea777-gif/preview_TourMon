import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 게스트 모드 로컬 저장소 — 서버 `user_eggs`/`user_monsters` 스키마와 최대한 대응
/// (init_plan.md DB 스키마 참고). 로그인(6단계) 시 이 row들을 서버로 마이그레이션할 예정이라
/// 컬럼을 최대한 맞춰둠.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbVersion = 5;

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
            target_steps INTEGER NOT NULL,
            steps_accumulated INTEGER NOT NULL DEFAULT 0,
            is_partner INTEGER NOT NULL DEFAULT 0,
            acquired_at TEXT NOT NULL,
            hatched_at TEXT
          )
        ''');
        await db.execute(_createUserMonstersSql);
        await db.execute(_createAppSettingsSql);
        await _addTourismSpotTitleColumns(db);
        await _createTourismSpotsCacheTable(db);
        await _createDailyStepsTable(db);
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
        if (oldVersion < 5) {
          await _createDailyStepsTable(db);
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

  /// v5 — 걸음수 일별 히스토리(Document/plan/later.md "마이페이지 — 걸음수 통계"). 원래는 마이페이지
  /// 통계용으로 미뤄뒀던 테이블인데, 지도 화면 파트너 알 박스의 "오늘 걸음수" 표시가 필요해져서
  /// 이 시점에 앞당겨 만듦(Document/temp.md 참고) — 나중에 5일 요약/히스토리 그리드를 붙일 때
  /// 스키마를 다시 안 건드리도록 later.md가 설계해둔 풀 테이블 그대로 생성. `date`는 KST 4시 경계
  /// 기준 날짜 키(day_key.dart `resetDayKey`와 동일 형식, YYYY-MM-DD).
  Future<void> _createDailyStepsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_steps (
        date TEXT PRIMARY KEY,
        steps INTEGER NOT NULL DEFAULT 0
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

  // 걸음수 기준선(last_raw_step_count) 등 단순 key-value 설정 저장용 — 4단계에서 처음 도입.
  static const _createAppSettingsSql = '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';
}
