import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// 단순 key-value 로컬 설정 저장소 — 4단계에서 pedometer 기준선(last_raw_step_count) 저장용으로 도입.
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
}
