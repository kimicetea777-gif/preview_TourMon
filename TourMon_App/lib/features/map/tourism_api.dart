import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../l10n/api_locale.dart';
import 'tourism_spot.dart';

/// TourMon Next.js API의 관광지 관련 엔드포인트 클라이언트.
class TourismApi {
  const TourismApi();

  /// 활성 관광지 전체(현재 약 1만 건) — `TourismSpotRepository`가 로컬 캐시 최초/재동기화에
  /// 사용(Document/temp.md "tour_spot 로컬 캐싱"). 마커 조회(`fetchSpotsInBounds`)와 좌표 중복
  /// 멤버 조회(`fetchSpotMembers`)는 이 캐시가 생기면서 로컬 쿼리로 대체돼 제거함 — 서버 라우트
  /// 자체는 구버전 호환용으로 남아있지만 이 앱은 더 이상 호출하지 않음.
  ///
  /// 응답이 커서(~4MB) JSON 파싱은 호출부가 `compute()`로 별도 isolate에 위임할 수 있도록,
  /// 여기서는 디코딩 없이 원문 문자열만 반환함.
  Future<String> fetchBulkSpots() async {
    final uri = Uri.parse('${ApiConfig.requireBaseUrl}/api/tourism-spots/bulk');
    final res = await http.get(uri).timeout(ApiConfig.requestTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch bulk tourism spots: ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<TourismSpotDetail> fetchSpotDetail(int id, {String locale = 'ko'}) async {
    final uri = withLocale(
      Uri.parse('${ApiConfig.requireBaseUrl}/api/tourism-spots/$id/detail'),
      locale,
    );

    final res = await http.get(uri).timeout(ApiConfig.requestTimeout);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch spot detail: ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return TourismSpotDetail.fromJson(json);
  }
}
