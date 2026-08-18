/// `GET /api/monsters/config`의 `species[]` 항목 매핑 모델.
class MonsterSpecies {
  final int id;
  final String attribute;
  final String rarity;
  final int dexNumber;
  final String imageUrl;
  final String? animationUrl;
  final String name;
  final String? description;

  MonsterSpecies({
    required this.id,
    required this.attribute,
    required this.rarity,
    required this.dexNumber,
    required this.imageUrl,
    required this.animationUrl,
    required this.name,
    required this.description,
  });

  factory MonsterSpecies.fromJson(Map<String, dynamic> json) {
    return MonsterSpecies(
      id: json['id'] as int,
      attribute: json['attribute'] as String,
      rarity: json['rarity'] as String,
      dexNumber: json['dexNumber'] as int,
      imageUrl: json['imageUrl'] as String,
      animationUrl: json['animationUrl'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

/// `attributeWeights[]` 항목 — content_type_id별 몬스터 종 후보 가중치.
class MonsterAttributeWeight {
  final int contentTypeId;
  final int monsterSpeciesId;
  final double weight;

  MonsterAttributeWeight({
    required this.contentTypeId,
    required this.monsterSpeciesId,
    required this.weight,
  });

  factory MonsterAttributeWeight.fromJson(Map<String, dynamic> json) {
    return MonsterAttributeWeight(
      contentTypeId: json['contentTypeId'] as int,
      monsterSpeciesId: json['monsterSpeciesId'] as int,
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

/// `rarityMultipliers[]` 항목 — 알 희귀도 × 몬스터 희귀도 배율.
class RarityWeightMultiplier {
  final String eggRarity;
  final String monsterRarity;
  final double multiplier;

  RarityWeightMultiplier({
    required this.eggRarity,
    required this.monsterRarity,
    required this.multiplier,
  });

  factory RarityWeightMultiplier.fromJson(Map<String, dynamic> json) {
    return RarityWeightMultiplier(
      eggRarity: json['eggRarity'] as String,
      monsterRarity: json['monsterRarity'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
    );
  }
}

/// 부화 결정 로직에 필요한 설정성 데이터 묶음 (4-4 섹션 "설정성 데이터").
class MonsterConfig {
  final List<MonsterSpecies> species;
  final List<MonsterAttributeWeight> attributeWeights;
  final List<RarityWeightMultiplier> rarityMultipliers;

  MonsterConfig({
    required this.species,
    required this.attributeWeights,
    required this.rarityMultipliers,
  });

  factory MonsterConfig.fromJson(Map<String, dynamic> json) {
    return MonsterConfig(
      species: (json['species'] as List<dynamic>)
          .map((e) => MonsterSpecies.fromJson(e as Map<String, dynamic>))
          .toList(),
      attributeWeights: (json['attributeWeights'] as List<dynamic>)
          .map((e) => MonsterAttributeWeight.fromJson(e as Map<String, dynamic>))
          .toList(),
      rarityMultipliers: (json['rarityMultipliers'] as List<dynamic>)
          .map((e) => RarityWeightMultiplier.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
