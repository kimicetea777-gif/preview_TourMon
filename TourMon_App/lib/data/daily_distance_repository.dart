import 'app_database.dart';
import 'day_key.dart';

/// 거리 일별 히스토리(`daily_distance`) 로컬 저장소. 거리 측정 이중화(Document/temp.md) 후로는
/// [DistanceTrackerService]가 GPS 델타/pedometer 백그라운드 diff를 적립 시점의 `resetDayKey`
/// (KST 4시 경계 기준 오늘)로 [addDistanceForDay]에 넘긴다. 지도 화면 파트너 알 박스의 "오늘
/// 거리" 표시용으로 [getTodayDistanceMeters]만 우선 추가 — 마이페이지 5일 요약/전체 히스토리
/// 조회는 아직 스코프 밖(Document/plan/later.md 참고).
class DailyDistanceRepository {
  const DailyDistanceRepository();

  Future<double> getTodayDistanceMeters() async {
    final db = await AppDatabase.instance.database;
    final today = resetDayKey(DateTime.now());
    final rows = await db.query(
      'daily_distance',
      columns: ['distance_meters'],
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['distance_meters'] as num).toDouble();
  }

  /// [DistanceTrackerService._creditDistance]가 GPS 델타/pedometer diff를 적립할 때마다 호출.
  Future<void> addDistanceForDay(String dayKey, double deltaMeters) async {
    if (deltaMeters <= 0) return;
    final db = await AppDatabase.instance.database;
    await db.rawInsert(
      '''
      INSERT INTO daily_distance (date, distance_meters) VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET distance_meters = distance_meters + excluded.distance_meters
      ''',
      [dayKey, deltaMeters],
    );
  }
}
