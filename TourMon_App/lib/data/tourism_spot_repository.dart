import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/tourism_config.dart';
import '../features/map/tourism_api.dart';
import '../features/map/tourism_spot.dart';
import 'app_database.dart';
import 'app_settings_repository.dart';

/// 관광지 로컬 캐싱(Document/temp.md "tour_spot 로컬 캐싱") — 뷰포트 이동마다 서버에 쿼리하는 대신
/// 로컬 sqlite(`tourism_spots`)에 전체를 캐싱해두고 팬/줌/좌표 중복 조회를 전부 로컬에서 처리.
/// `user_eggs`/`user_monsters`와 달리 유저 소유 데이터가 아니라 공용 참조 캐시.
class TourismSpotRepository {
  const TourismSpotRepository();

  static const _lastSyncedAtKey = 'tourism_spots_last_synced_at';
  static const _api = TourismApi();
  static const _settings = AppSettingsRepository();

  // 초기 동기화/백그라운드 재동기화가 겹쳐 중복 실행되지 않게 하는 가드 — static이라 여러
  // TourismSpotRepository 인스턴스(전부 const라 사실 동일 인스턴스지만)에서도 공유됨.
  static Future<void>? _inFlightSync;

  Future<bool> hasLocalData() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM tourism_spots');
    return ((result.first['c'] as int?) ?? 0) > 0;
  }

  /// 마지막 동기화 이후 `TourismConfig.syncStaleThreshold`가 지났는지 — 한 번도 동기화 안 했으면
  /// (키 없음) 당연히 stale 취급.
  Future<bool> isStale() async {
    final lastSyncedAt = await _settings.getValue(_lastSyncedAtKey);
    if (lastSyncedAt == null) return true;
    final elapsed = DateTime.now().difference(DateTime.parse(lastSyncedAt));
    return elapsed > TourismConfig.syncStaleThreshold;
  }

  /// 전체 재다운로드 후 로컬 테이블 통째 교체(델타 없음, temp.md 3번 "검토했으나 기각" 참고).
  /// 새 데이터를 성공적으로 다 받은 뒤에만 트랜잭션으로 교체하므로, 오프라인 등으로 실패하면
  /// 기존 캐시가 그대로 남아 지도 마커 표시가 끊기지 않음. 동시 호출은 진행 중인 걸 그대로 공유.
  Future<void> syncBulk() {
    return _inFlightSync ??= _syncBulk().whenComplete(() => _inFlightSync = null);
  }

  Future<void> _syncBulk() async {
    final body = await _api.fetchBulkSpots();
    // JSON 파싱(1만 건)은 메인 isolate에서 하면 첫 실행 시 화면이 버벅일 수 있어 별도 isolate로
    // 위임 — sqflite Database 핸들은 isolate 간 공유가 안 돼서 insert 자체는 아래(메인 isolate)에서.
    final rows = await compute(_parseBulkSpotRows, body);

    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('tourism_spots');
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert('tourism_spots', row);
      }
      await batch.commit(noResult: true);
    });
    await _settings.setValue(_lastSyncedAtKey, DateTime.now().toIso8601String());
  }

  /// 마커 조회 — 대표 spot만, 뷰포트(bounds) 안에 있는 것만. 서버 왕복 없이 즉시 반환됨.
  Future<List<TourismSpot>> getSpotsInBounds(LatLngBounds bounds) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'tourism_spots',
      where: 'is_representative = 1 AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ?',
      whereArgs: [bounds.south, bounds.north, bounds.west, bounds.east],
    );
    return rows.map(_rowToTourismSpot).toList();
  }

  /// 좌표 중복(같은 건물 내 여러 매장) 리스트 — 예전 `GET /api/tourism-spots/[id]/members`와 동일한
  /// 규칙(카테고리별 개수 + 임계치 이하일 때만 실제 spots)을 로컬 쿼리로 재현.
  Future<TourismSpotMembers> getMembers(int representativeId, {int? contentTypeId}) async {
    final db = await AppDatabase.instance.database;
    final countRows = await db.rawQuery(
      '''
      SELECT content_type_id AS contentTypeId, COUNT(*) AS count
      FROM tourism_spots
      WHERE representative_spot_id = ?
      GROUP BY content_type_id
      ''',
      [representativeId],
    );
    final byContentType = countRows
        .map(
          (r) => ContentTypeCount(
            contentTypeId: r['contentTypeId'] as int,
            count: r['count'] as int,
          ),
        )
        .toList();
    final totalCount = byContentType.fold<int>(0, (sum, e) => sum + e.count);

    final shouldReturnSpots =
        contentTypeId != null || totalCount <= TourismConfig.duplicateSpotListFilterThreshold;

    var spots = const <TourismSpot>[];
    if (shouldReturnSpots) {
      final whereArgs = <Object?>[representativeId];
      var where = 'representative_spot_id = ?';
      if (contentTypeId != null) {
        where += ' AND content_type_id = ?';
        whereArgs.add(contentTypeId);
      }
      final rows = await db.query(
        'tourism_spots',
        where: where,
        whereArgs: whereArgs,
        // content_id는 TEXT 컬럼이라 그냥 정렬하면 자릿수가 다른 값끼리 사전식으로 잘못 정렬됨 —
        // 서버 dedupe-spots.ts/members 라우트의 `::bigint` 캐스트와 동일한 이유로 정수 캐스트.
        orderBy: 'CAST(content_id AS INTEGER) ASC',
      );
      spots = rows.map(_rowToTourismSpot).toList();
    }

    return TourismSpotMembers(totalCount: totalCount, byContentType: byContentType, spots: spots);
  }

  TourismSpot _rowToTourismSpot(Map<String, dynamic> row) {
    return TourismSpot(
      id: row['id'] as int,
      contentId: row['content_id'] as String,
      title: row['title'] as String,
      titleEn: row['title_en'] as String?,
      firstImage: row['first_image'] as String?,
      addr1: row['addr1'] as String?,
      addr2: row['addr2'] as String?,
      contentTypeId: row['content_type_id'] as int,
      cpyrhtDivCd: row['cpyrht_div_cd'] as String?,
      memberCount: row['member_count'] as int,
      position: LatLng((row['lat'] as num).toDouble(), (row['lng'] as num).toDouble()),
    );
  }
}

/// `compute()`에 넘기는 콜백은 top-level(또는 static) 함수여야 해서 클래스 밖에 둠 — `GET
/// /api/tourism-spots/bulk` 응답 문자열을 파싱해서 sqflite insert에 바로 쓸 수 있는
/// `Map<String, dynamic>`(컬럼명 기준) 리스트로 변환.
List<Map<String, dynamic>> _parseBulkSpotRows(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final spots = json['spots'] as List<dynamic>;
  return spots.map((e) {
    final m = e as Map<String, dynamic>;
    return {
      'id': m['id'] as int,
      'content_id': m['contentId'] as String,
      'title': m['title'] as String,
      'title_en': m['titleEn'] as String?,
      'addr1': m['addr1'] as String?,
      'addr2': m['addr2'] as String?,
      'first_image': m['firstImage'] as String?,
      'content_type_id': m['contentTypeId'] as int,
      'cpyrht_div_cd': m['cpyrhtDivCd'] as String?,
      'lat': (m['lat'] as num).toDouble(),
      'lng': (m['lng'] as num).toDouble(),
      'representative_spot_id': m['representativeSpotId'] as int,
      'is_representative': (m['isRepresentative'] as bool) ? 1 : 0,
      'member_count': m['memberCount'] as int,
    };
  }).toList();
}
