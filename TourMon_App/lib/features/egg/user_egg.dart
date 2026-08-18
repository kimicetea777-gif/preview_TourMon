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
  final int targetSteps;
  final int stepsAccumulated;
  final bool isPartner;
  final DateTime acquiredAt;
  final DateTime? hatchedAt;

  UserEgg({
    required this.id,
    required this.tourismSpotId,
    required this.tourismSpotTitle,
    required this.contentTypeId,
    required this.eggTypeId,
    required this.rarity,
    required this.name,
    required this.description,
    required this.targetSteps,
    required this.stepsAccumulated,
    required this.isPartner,
    required this.acquiredAt,
    required this.hatchedAt,
  });

  bool get isReadyToHatch => hatchedAt == null && stepsAccumulated >= targetSteps;

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
      targetSteps: map['target_steps'] as int,
      stepsAccumulated: map['steps_accumulated'] as int,
      isPartner: (map['is_partner'] as int) == 1,
      acquiredAt: DateTime.parse(map['acquired_at'] as String),
      hatchedAt: map['hatched_at'] == null ? null : DateTime.parse(map['hatched_at'] as String),
    );
  }

  /// 6단계 Phase 5 — 서버 복구(`GET /api/eggs`) 응답 매핑. 서버는 미부화 알만 내려주므로
  /// `hatchedAt`은 항상 null(Document/study_folder/6-5_... 참고).
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
      targetSteps: json['targetSteps'] as int,
      stepsAccumulated: json['stepsAccumulated'] as int,
      isPartner: json['isPartner'] as bool,
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
      'target_steps': targetSteps,
      'steps_accumulated': stepsAccumulated,
      'is_partner': isPartner ? 1 : 0,
      'acquired_at': acquiredAt.toIso8601String(),
      'hatched_at': hatchedAt?.toIso8601String(),
    };
  }
}
