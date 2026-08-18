import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import 'monster_species.dart';
import 'rarity_colors.dart';
import 'user_monster.dart';

/// 5단계 — 도감 상세 화면. 잡은 종의 스탯/설명 + 개체별 획득 기록(장소/날짜) 목록을 보여준다.
/// `tourismSpotTitle`은 v3 스키마 이후 저장된 개체만 있음 — 그 이전에 부화한 개체는 null이라
/// 날짜만 표시(장소 텍스트가 아예 없던 예전 동작으로 자연 폴백).
class DexDetailScreen extends StatelessWidget {
  final MonsterSpecies species;
  final List<UserMonster> encounters;

  const DexDetailScreen({super.key, required this.species, required this.encounters});

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = rarityColor(species.rarity);
    return Scaffold(
      appBar: AppBar(title: Text(species.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: species.imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => Icon(Icons.pets, size: 80, color: color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '#${species.dexNumber.toString().padLeft(3, '0')}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Center(
            child: Text(species.name, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(attributeLabel(context, species.attribute))),
                Chip(
                  label: Text(rarityLabel(context, species.rarity)),
                  backgroundColor: color.withValues(alpha: 0.2),
                ),
                Chip(label: Text(l10n.ownedCountLabel(encounters.length))),
              ],
            ),
          ),
          if (species.description != null) ...[
            const SizedBox(height: 16),
            Text(species.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Text(l10n.acquisitionHistoryLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final encounter in encounters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome),
              title: Text(encounter.tourismSpotTitle ?? _formatDate(encounter.hatchedAt)),
              subtitle: encounter.tourismSpotTitle == null
                  ? null
                  : Text(_formatDate(encounter.hatchedAt)),
            ),
        ],
      ),
    );
  }
}
