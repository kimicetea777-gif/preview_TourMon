import 'monster_species.dart';

/// 로컬 SQLite `user_monsters` row 매핑 모델 — 부화 완료된 몬스터(도감).
/// 서버 스키마는 monster_species_id로 참조하고 이름/이미지는 JOIN해서 내려주지만, 게스트 로컬본은
/// 오프라인 표시를 위해 부화 시점 스냅샷(attribute/rarity/name/imageUrl 등)을 그대로 저장.
class UserMonster {
  final String id;
  final int monsterSpeciesId;
  final String? eggId;
  final int? tourismSpotId;
  final String? tourismSpotTitle; // 획득 장소 이름 스냅샷 — 도감 상세화면 획득 기록에 표시
  final String attribute;
  final String rarity;
  final int dexNumber;
  final String imageUrl;
  final String name;
  final String? description;
  final DateTime hatchedAt;

  UserMonster({
    required this.id,
    required this.monsterSpeciesId,
    required this.eggId,
    required this.tourismSpotId,
    required this.tourismSpotTitle,
    required this.attribute,
    required this.rarity,
    required this.dexNumber,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.hatchedAt,
  });

  factory UserMonster.fromMap(Map<String, Object?> map) {
    return UserMonster(
      id: map['id'] as String,
      monsterSpeciesId: map['monster_species_id'] as int,
      eggId: map['egg_id'] as String?,
      tourismSpotId: map['tourism_spot_id'] as int?,
      tourismSpotTitle: map['tourism_spot_title'] as String?,
      attribute: map['attribute'] as String,
      rarity: map['rarity'] as String,
      dexNumber: map['dex_number'] as int,
      imageUrl: map['image_url'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      hatchedAt: DateTime.parse(map['hatched_at'] as String),
    );
  }

  /// 6단계 Phase 5 — 서버 복구(`GET /api/monsters/dex`) 응답 매핑
  /// (Document/study_folder/6-5_... 참고).
  factory UserMonster.fromRestoreJson(Map<String, dynamic> json) {
    return UserMonster(
      id: json['id'] as String,
      monsterSpeciesId: json['monsterSpeciesId'] as int,
      eggId: json['eggId'] as String?,
      tourismSpotId: json['tourismSpotId'] as int?,
      tourismSpotTitle: json['tourismSpotTitle'] as String?,
      attribute: json['attribute'] as String,
      rarity: json['rarity'] as String,
      dexNumber: json['dexNumber'] as int,
      imageUrl: json['imageUrl'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      hatchedAt: DateTime.parse(json['hatchedAt'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'monster_species_id': monsterSpeciesId,
      'egg_id': eggId,
      'tourism_spot_id': tourismSpotId,
      'tourism_spot_title': tourismSpotTitle,
      'attribute': attribute,
      'rarity': rarity,
      'dex_number': dexNumber,
      'image_url': imageUrl,
      'name': name,
      'description': description,
      'hatched_at': hatchedAt.toIso8601String(),
    };
  }

  /// 부화 시점 스냅샷으로 `MonsterSpecies`를 재구성 — `/api/monsters/config` 조회가 실패해도(오프라인)
  /// 이미 잡은 몬스터는 도감에 표시할 수 있게 하려는 용도(도감 화면 오프라인 폴백). `animationUrl`은
  /// 로컬에 저장하지 않아 항상 null.
  MonsterSpecies toSpecies() {
    return MonsterSpecies(
      id: monsterSpeciesId,
      attribute: attribute,
      rarity: rarity,
      dexNumber: dexNumber,
      imageUrl: imageUrl,
      animationUrl: null,
      name: name,
      description: description,
    );
  }
}
