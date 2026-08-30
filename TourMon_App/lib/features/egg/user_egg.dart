import '../../config/game_config.dart';

/// 로컬 SQLite `user_eggs` row 매핑 모델.
class UserEgg {
  final String id;
  final int? tourismSpotId;
  final String? tourismSpotTitle; // 획득 장소 이름 스냅샷 — 도감 상세화면에 조회 API 없이 표시하는 용도
  final int? contentTypeId; // 획득 장소의 content_type_id 스냅샷 — 부화 시 몬스터 결정 1차 조건
  final int eggTypeId;
  final String rarity;
  final String name;
  final String? description;
  final int targetDistanceMeters;
  final int distanceAccumulatedMeters;
  final bool isPartner;
  final DateTime acquiredAt;
  final DateTime? hatchedAt;

  /// 서버로 이관된 시각. NULL이면 이 알은 서버엔 아직 `egg_vouchers` row로만 존재함(게스트 획득
  /// 후 마이그레이션 미완/거부) — 회원 `user_eggs`엔 없으므로 서버 부화(POST /api/eggs/[id]/hatch)를
  /// 부르면 404가 남. 값이 있으면 회원 테이블로 이관 완료라 서버 부화 가능
  /// (migration_service.dart, egg_repository.dart markSynced/insertEgg 참고).
  final DateTime? syncedAt;

  UserEgg({
    required this.id,
    required this.tourismSpotId,
    required this.tourismSpotTitle,
    required this.contentTypeId,
    required this.eggTypeId,
    required this.rarity,
    required this.name,
    required this.description,
    required this.targetDistanceMeters,
    required this.distanceAccumulatedMeters,
    required this.isPartner,
    required this.acquiredAt,
    required this.hatchedAt,
    this.syncedAt,
  });

  bool get isReadyToHatch =>
      hatchedAt == null && distanceAccumulatedMeters >= targetDistanceMeters;

  /// 게스트(로그인 전) 알의 유통기한 시각 — `acquiredAt` + `GameConfig.guestEggShelfLife`.
  /// 로그인한 회원 알엔 의미 없음(호출부가 게스트일 때만 씀).
  DateTime get guestShelfLifeExpiresAt =>
      acquiredAt.add(GameConfig.guestEggShelfLife);

  /// 지금 기준 유통기한까지 남은 시간(음수면 이미 만료). 화면 표시/경고색 판정용.
  Duration get guestShelfLifeRemaining =>
      guestShelfLifeExpiresAt.difference(DateTime.now());

  /// 유통기한이 지나 "굳어버린" 게스트 알인지 — 부화 차단 + 보관함 정리 트리거.
  bool get isGuestShelfLifeExpired =>
      DateTime.now().isAfter(guestShelfLifeExpiresAt);

  factory UserEgg.fromMap(Map<String, Object?> map) {
    return UserEgg(
      id: map['id'] as String,
      tourismSpotId: map['tourism_spot_id'] as int?,
      tourismSpotTitle: map['tourism_spot_title'] as String?,
      contentTypeId: map['content_type_id'] as int?,
      eggTypeId: map['egg_type_id'] as int,
      rarity: map['rarity'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetDistanceMeters: map['target_distance_meters'] as int,
      distanceAccumulatedMeters: map['distance_accumulated_meters'] as int,
      isPartner: (map['is_partner'] as int) == 1,
      acquiredAt: DateTime.parse(map['acquired_at'] as String),
      hatchedAt: map['hatched_at'] == null
          ? null
          : DateTime.parse(map['hatched_at'] as String),
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
    );
  }

  /// 6단계 Phase 5 — 서버 복구(`GET /api/eggs`) 응답 매핑. 서버는 미부화 알만 내려주므로
  /// `hatchedAt`은 항상 null(Document/study_folder/6-5_... 참고).
  ///
  /// 파트너는 순수 기기 로컬 상태라 서버 응답에 `isPartner`가 없음(Document/temp.md Part 1) —
  /// 복구된 알은 항상 non-partner로 로컬에 들어가고, 유저의 최근 파트너 선택(로컬)이 그대로 유지됨.
  ///
  /// `syncedAt`은 여기서 안 채움 — 이 객체는 곧장 `EggRepository.upsertFromServer`가 `synced_at`을
  /// 명시적으로 박아 DB에 넣는 데만 쓰이고(그 값이 `toMap()`보다 우선), 그 뒤론 항상 `fromMap`으로
  /// 다시 읽힘. 복구 객체에서 직접 `.syncedAt`을 읽는 코드는 없음.
  factory UserEgg.fromRestoreJson(Map<String, dynamic> json) {
    return UserEgg(
      id: json['id'] as String,
      tourismSpotId: json['tourismSpotId'] as int?,
      tourismSpotTitle: json['tourismSpotTitle'] as String?,
      contentTypeId: json['contentTypeId'] as int?,
      eggTypeId: json['eggTypeId'] as int,
      rarity: json['rarity'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      targetDistanceMeters: json['targetDistanceMeters'] as int,
      distanceAccumulatedMeters: json['distanceAccumulatedMeters'] as int,
      isPartner: false,
      acquiredAt: DateTime.parse(json['acquiredAt'] as String),
      hatchedAt: null,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'tourism_spot_id': tourismSpotId,
      'tourism_spot_title': tourismSpotTitle,
      'content_type_id': contentTypeId,
      'egg_type_id': eggTypeId,
      'rarity': rarity,
      'name': name,
      'description': description,
      'target_distance_meters': targetDistanceMeters,
      'distance_accumulated_meters': distanceAccumulatedMeters,
      'is_partner': isPartner ? 1 : 0,
      'acquired_at': acquiredAt.toIso8601String(),
      'hatched_at': hatchedAt?.toIso8601String(),
    };
  }
}
