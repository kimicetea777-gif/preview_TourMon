import 'package:latlong2/latlong.dart';

/// 마커/미리보기 팝업용 모델(locationBasedList2 대응 필드) — `TourismSpotRepository`가 로컬 캐시
/// (`tourism_spots` sqlite 테이블)에서 조회한 row를 매핑해 만듦. 서버 JSON을 직접 매핑하던
/// `fromJson`은 로컬 캐싱 도입(Document/temp.md "tour_spot 로컬 캐싱")으로 안 쓰게 돼서 제거.
class TourismSpot {
  final int id;
  final String contentId;
  final String title;
  final String? titleEn;
  final String? firstImage;
  final String? addr1;
  final String? addr2;
  final int contentTypeId;
  final String? cpyrhtDivCd;
  final LatLng position;
  // 이 spot이 대표인 좌표 중복 클러스터의 멤버 수(자기 자신 포함, 1이면 중복 없음) — dedup 배치
  // (scripts/tour-sync/dedupe-spots.ts)가 미리 계산해둔 값. `/api/tourism-spots/[id]/detail`
  // 응답에는 이 필드가 없어서, TourismSpotDetail이 아니라 여기 마커 모델에만 있음.
  final int memberCount;

  TourismSpot({
    required this.id,
    required this.contentId,
    required this.title,
    required this.titleEn,
    required this.firstImage,
    required this.addr1,
    required this.addr2,
    required this.contentTypeId,
    required this.cpyrhtDivCd,
    required this.position,
    required this.memberCount,
  });
}

/// 좌표 중복(같은 건물 내 여러 매장) 리스트 — `TourismSpotRepository.getMembers()`가 로컬 캐시에서
/// 조회해 구성(예전엔 `GET /api/tourism-spots/{id}/members` 응답을 그대로 매핑했음).
class TourismSpotMembers {
  final int totalCount;
  final List<ContentTypeCount> byContentType;
  // totalCount가 DUPLICATE_SPOT_LIST_FILTER_THRESHOLD 이하이거나 contentTypeId로 필터링한
  // 경우에만 채워짐 — 그 외엔 빈 리스트(클라이언트는 byContentType으로 카테고리 버튼만 그림).
  final List<TourismSpot> spots;

  TourismSpotMembers({
    required this.totalCount,
    required this.byContentType,
    required this.spots,
  });
}

class ContentTypeCount {
  final int contentTypeId;
  final int count;

  ContentTypeCount({required this.contentTypeId, required this.count});
}

/// `GET /api/tourism-spots/{id}/detail` 응답 매핑 모델 — "더보기" 상세.
class TourismSpotDetail {
  final String? overview;
  final String? homepage;
  // en 요청인데 매칭된 영문 content가 없어 서버가 국문으로 폴백했으면 false — 영어 화면에서
  // overview가 사실은 한국어임을 화면에 표시하기 위한 구분값(실기기 확인, Document/temp.md 참고).
  final bool usedEnglish;
  final List<TourismSpotImage> images;

  TourismSpotDetail({
    required this.overview,
    required this.homepage,
    required this.usedEnglish,
    required this.images,
  });

  factory TourismSpotDetail.fromJson(Map<String, dynamic> json) {
    return TourismSpotDetail(
      overview: json['overview'] as String?,
      homepage: json['homepage'] as String?,
      usedEnglish: json['usedEnglish'] as bool? ?? true,
      images: (json['images'] as List<dynamic>)
          .map((e) => TourismSpotImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TourismSpotImage {
  final String originImgUrl;
  final String smallImageUrl;
  final String? cpyrhtDivCd;

  TourismSpotImage({
    required this.originImgUrl,
    required this.smallImageUrl,
    required this.cpyrhtDivCd,
  });

  factory TourismSpotImage.fromJson(Map<String, dynamic> json) {
    return TourismSpotImage(
      originImgUrl: json['originImgUrl'] as String,
      smallImageUrl: json['smallImageUrl'] as String,
      cpyrhtDivCd: json['cpyrhtDivCd'] as String?,
    );
  }

  /// Type1(가공 허용)만 크롭 가능, 그 외(Type3 등)는 원본 그대로 표시 (4-5 섹션 원칙).
  bool get allowsCrop => cpyrhtDivCd == 'Type1';
}
