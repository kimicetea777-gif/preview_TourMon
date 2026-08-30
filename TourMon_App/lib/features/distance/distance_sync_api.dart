import 'dart:convert';

import '../auth/authorized_api_client.dart';

/// 6단계 Phase 5 후속 하드닝 — 거리 서버 동기화
/// (Document/temp.md "파트너 알 중복 설정 / 거리 서버 동기화 재검토").
///
/// Part 1: 파트너는 순수 기기 로컬 상태라 서버엔 파트너 개념이 없음 — 이번에 거리를 적립할 파트너
///   알 id 목록(`partnerEggIds`)을 매 sync마다 클라가 직접 실어보낸다.
/// Part 3-A: 서버 응답의 파트너 알 누적값을 받아 호출부가 로컬을 서버 값에 수렴시킨다(회원은
///   distance_accumulated_meters가 서버 authoritative). 예전 주석의 "로컬이 항상 진짜 값이라 응답
///   불필요"는 이 변경으로 뒤집힘 — 게스트는 여전히 로컬 authoritative지만 회원은 서버 우선.
class DistanceSyncApi {
  const DistanceSyncApi(this._client);

  final AuthorizedApiClient _client;

  /// 반환: 서버가 확인한 파트너 알별 누적 거리(id → distanceAccumulatedMeters). 본인 소유·미부화
  /// 알만 포함되므로, 호출부는 이 맵으로 로컬 값을 그대로 덮어쓰면 됨.
  Future<Map<String, int>> sync(
    int deltaDistanceMeters, {
    required bool mockDetected,
    required List<String> partnerEggIds,
  }) async {
    final res = await _client.post(
      '/api/distance/sync',
      body: {
        'deltaDistanceMeters': deltaDistanceMeters,
        'mockDetected': mockDetected,
        'partnerEggIds': partnerEggIds,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Distance sync failed: ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final eggs = json['eggs'] as List<dynamic>? ?? [];
    return {
      for (final e in eggs)
        (e as Map<String, dynamic>)['id'] as String:
            (e['distanceAccumulatedMeters'] as num).toInt(),
    };
  }
}
