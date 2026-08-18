import 'app_database.dart';
import 'day_key.dart';

/// 걸음수 일별 히스토리(`daily_steps`) 로컬 저장소. 지금은 지도 화면 파트너 알 박스의 "오늘 걸음수"
/// 표시용으로 [getTodaySteps]만 우선 추가 — 마이페이지 5일 요약/전체 히스토리 조회는 아직 스코프
/// 밖(Document/plan/later.md 참고), 필요해지면 이 클래스에 조회 메서드만 추가하면 됨.
class DailyStepsRepository {
  const DailyStepsRepository();

  Future<int> getTodaySteps() async {
    final db = await AppDatabase.instance.database;
    final today = resetDayKey(DateTime.now());
    final rows = await db.query(
      'daily_steps',
      columns: ['steps'],
      where: 'date = ?',
      whereArgs: [today],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['steps'] as int;
  }

  /// `StepTrackerService`의 daily_steps 전용 세션 기준선 로직이 오늘 날짜 row에 델타를 적립할 때 사용.
  Future<void> addStepsToday(int deltaSteps) async {
    if (deltaSteps <= 0) return;
    final db = await AppDatabase.instance.database;
    final today = resetDayKey(DateTime.now());
    await db.rawInsert(
      '''
      INSERT INTO daily_steps (date, steps) VALUES (?, ?)
      ON CONFLICT(date) DO UPDATE SET steps = steps + excluded.steps
      ''',
      [today, deltaSteps],
    );
  }
}
