import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// 단순 key-value 로컬 설정 저장소 — 4단계에서 걸음수 기준선 저장용으로 도입, Health Connect
/// 전환(Document/temp.md "통합 결정") 후엔 거리 동기화 기준 시각(distance_last_synced_at) 등을 저장.
class AppSettingsRepository {
  const AppSettingsRepository();

  Future<String?> getValue(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setValue(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteValue(String key) async {
    final db = await AppDatabase.instance.database;
    await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }
}
