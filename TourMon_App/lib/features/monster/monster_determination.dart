import 'dart:math';

import 'monster_species.dart';

/// 4단계 — 부화 시 몬스터 결정 로직 (init_plan.md 4-3 섹션).
/// 게스트 모드는 이 계산을 클라이언트에서 직접 함 — 순수 확률 계산이라 알 획득의 위치 검증처럼
/// 서버가 반드시 필요한 이유가 없고, 회원 대상 위조 방지(서버 authoritative 판정)는 6단계에서
/// 별도로 붙임(tourmon_planning_status 메모리 "회원 알 위조 검증의 남은 구멍" 논의 참고).
///
/// 1차: 획득 장소의 content_type_id → monster_attribute_weights로 후보 종+가중치 결정
/// 2차: 알 rarity × 몬스터 rarity를 rarity_weight_multipliers로 곱해서 최종 확률 산출
MonsterSpecies determineMonster({
  required String eggRarity,
  required int? contentTypeId,
  required MonsterConfig config,
  Random? random,
}) {
  if (config.species.isEmpty) {
    throw StateError('Monster config data is empty');
  }
  final rng = random ?? Random();
  final speciesById = {for (final s in config.species) s.id: s};

  // 1차 후보: 해당 content_type의 가중치 테이블. 스팟 정보가 없거나(구버전 로컬 데이터 등)
  // 매칭되는 행이 없으면 전체 종을 균등 가중치로 폴백.
  final candidateWeights = <int, double>{};
  if (contentTypeId != null) {
    for (final w in config.attributeWeights) {
      if (w.contentTypeId == contentTypeId && w.weight > 0) {
        candidateWeights[w.monsterSpeciesId] = w.weight;
      }
    }
  }
  if (candidateWeights.isEmpty) {
    for (final s in config.species) {
      candidateWeights[s.id] = 1;
    }
  }

  // 2차: 알 희귀도 × 몬스터 희귀도 배율 적용.
  final multiplierByMonsterRarity = {
    for (final m in config.rarityMultipliers)
      if (m.eggRarity == eggRarity) m.monsterRarity: m.multiplier,
  };

  final finalWeights = <int, double>{};
  for (final entry in candidateWeights.entries) {
    final species = speciesById[entry.key];
    if (species == null) continue;
    final multiplier = multiplierByMonsterRarity[species.rarity] ?? 1;
    final weight = entry.value * multiplier;
    if (weight > 0) finalWeights[entry.key] = weight;
  }

  // 배율 적용 후 전멸(전부 0)하는 극단적 케이스 대비 — 원래 1차 후보로 균등 폴백.
  final pool = finalWeights.isNotEmpty ? finalWeights : candidateWeights;

  final totalWeight = pool.values.fold<double>(0, (sum, w) => sum + w);
  var roll = rng.nextDouble() * totalWeight;
  for (final entry in pool.entries) {
    if (roll < entry.value) {
      return speciesById[entry.key]!;
    }
    roll -= entry.value;
  }
  return speciesById[pool.keys.last]!;
}

/// 알 정보 시트(`egg_type_info_sheet.dart`)의 "부화 시 몬스터 등급 확률" 표시용 — [determineMonster]의
/// 2차 계산(알 rarity × 몬스터 rarity 배율)을 그대로 재현해서 등급별 최종 확률(%)을 계산한다.
/// 1차 후보(장소별 가중치, `monster_attribute_weights`)는 반영하지 않고 항상 종별 균등 가중치로
/// 계산 — 지금 이 테이블이 모든 content_type×종 조합에 균등(1)으로 시드돼 있어 장소가 결과에
/// 영향을 안 주므로 [determineMonster]와 정확히 같은 확률이 나온다. 나중에 장소별 편향이 실제로
/// 생기면(init_plan.md 4-4 섹션 TBD) 이 함수도 `contentTypeId`를 받도록 같이 손볼 것.
Map<String, double> monsterRarityProbabilities(String eggRarity, MonsterConfig config) {
  final multiplierByMonsterRarity = {
    for (final m in config.rarityMultipliers)
      if (m.eggRarity == eggRarity) m.monsterRarity: m.multiplier,
  };
  final weightByRarity = <String, double>{};
  for (final species in config.species) {
    final multiplier = multiplierByMonsterRarity[species.rarity] ?? 1;
    if (multiplier <= 0) continue;
    weightByRarity[species.rarity] = (weightByRarity[species.rarity] ?? 0) + multiplier;
  }
  final total = weightByRarity.values.fold<double>(0, (sum, w) => sum + w);
  if (total <= 0) return {};
  return {
    for (final entry in weightByRarity.entries) entry.key: entry.value / total * 100,
  };
}
