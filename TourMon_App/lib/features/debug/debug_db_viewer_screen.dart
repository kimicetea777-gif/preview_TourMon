import 'package:flutter/material.dart';

import '../../data/app_database.dart';

/// 디버그 전용(--dart-define=DEBUG_MODE=true) — 실기기에 설치된 상태에서 로컬 sqlite(tourmon.db)를
/// PC 연결(adb run-as) 없이 앱 안에서 바로 조회하기 위한 화면(2026-08-26, 사용자 요청 — 삼성
/// 헬스에서는 거리가 늘어나는데 TourMon(daily_distance/app_settings)엔 반영 안 되는 문제를 직접
/// 확인하려는 목적). map_screen.dart의 다른 디버그 도구와 같은 DebugConfig.isEnabled 가드로만
/// 노출되므로 릴리즈 빌드엔 이 화면 진입점 자체가 없음.
class DebugDbViewerScreen extends StatefulWidget {
  const DebugDbViewerScreen({super.key});

  @override
  State<DebugDbViewerScreen> createState() => _DebugDbViewerScreenState();
}

class _DebugDbViewerScreenState extends State<DebugDbViewerScreen> {
  late Future<List<String>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _tablesFuture = _loadTables();
  }

  Future<List<String>> _loadTables() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[디버그] 로컬 DB (tourmon.db)')),
      body: FutureBuilder<List<String>>(
        future: _tablesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('테이블 목록 조회 실패: ${snapshot.error}'));
          }
          final tables = snapshot.data!;
          return ListView.builder(
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              return ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(table),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _DebugTableRowsScreen(tableName: table),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DebugTableRowsScreen extends StatefulWidget {
  const _DebugTableRowsScreen({required this.tableName});

  final String tableName;

  @override
  State<_DebugTableRowsScreen> createState() => _DebugTableRowsScreenState();
}

class _DebugTableRowsScreenState extends State<_DebugTableRowsScreen> {
  // 테이블이 너무 크면(tourism_spots는 1만 건 안팎) 화면이 버벅일 수 있어 최근 N건만 —
  // rowid DESC로 "가장 최근에 insert된 행"부터 보이게 함(daily_distance/app_settings처럼 값이
  // 갱신되는지 확인할 땐 최신 행이 먼저 보이는 게 유용).
  static const _rowLimit = 200;

  late Future<List<Map<String, Object?>>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _loadRows();
  }

  Future<List<Map<String, Object?>>> _loadRows() async {
    final db = await AppDatabase.instance.database;
    try {
      return await db.rawQuery(
        'SELECT * FROM ${widget.tableName} ORDER BY rowid DESC LIMIT $_rowLimit',
      );
    } catch (_) {
      // WITHOUT ROWID 테이블 등 rowid가 없는 경우의 방어적 폴백 — 이 앱엔 없지만 만약을 대비.
      return await db.query(widget.tableName, limit: _rowLimit);
    }
  }

  Future<void> _refresh() async {
    final rows = _loadRows();
    setState(() => _rowsFuture = rows);
    await rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tableName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _rowsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('조회 실패: ${snapshot.error}'));
          }
          final rows = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('행이 없습니다')),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          for (final c in rows.first.keys) DataColumn(label: Text(c)),
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              cells: [
                                for (final c in row.keys) DataCell(Text('${row[c] ?? '-'}')),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
