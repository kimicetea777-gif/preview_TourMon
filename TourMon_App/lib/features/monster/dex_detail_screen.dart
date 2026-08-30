import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/sketch/sketch_theme.dart';
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

  const DexDetailScreen({
    super.key,
    required this.species,
    required this.encounters,
  });

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = rarityColor(species.rarity);
    // 지도/알 보관함/도감과 같은 그림책+연필 스케치 테마를 이 화면 서브트리에만 지역 적용
    // (2026-08-26, 사용자 요청 — config/sketch/sketch_theme.dart 주석 참고).
    return Theme(
      data: SketchTheme.themeData,
      // Builder로 새 context를 얻어야 함 — 이 메서드의 원래 context는 위에 감싼 Theme보다
      // 상위(부모 라우트) 위치라, 아래에서 Theme.of(context)를 그대로 쓰면 SketchTheme이 아니라
      // 상위의 앱 전역 다크 테마가 잡힘(실기기 확인 — 본문 텍스트가 다크 테마용 옅은 색으로 나와
      // 크림 배경 위에서 거의 안 보이는 문제가 있었음, 2026-08-26).
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(species.name)),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            children: [
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  // 원형 클리핑(ClipOval)을 없앰(2026-08-26 사용자 요청) — 아트 여백/구도가 정사각형
                  // 기준이라 원으로 자르면 몬스터 일부가 잘려 보였음. 이제 자르지 않고 그대로 보여줌.
                  // 도감 상세는 움직이는 아트(animationUrl)를 우선 사용 — 목록(dex_screen.dart)만
                  // 정적 썸네일(imageUrl)을 씀(2026-08-26 사용자 결정). 오프라인 폴백 종
                  // (user_monster.dart의 toSpecies())처럼 animationUrl이 없는 경우만 imageUrl로.
                  child: CachedNetworkImage(
                    imageUrl: species.animationUrl ?? species.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) =>
                        Icon(Icons.pets, size: 80, color: color),
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
                child: Text(
                  species.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 8,
                  // 속성 Chip 제거(2026-08-26 사용자 결정) — 지금은 속성을 안 씀, 몬스터가 본격적으로
                  // 늘어날 때 다시 도입 예정(Document/temp.md 참고).
                  children: [
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
                // 좌우가 화면 끝에 완전히 맞붙지 않도록 indent/endIndent로 여백을 둠
                // (2026-08-26, 사용자 요청).
                const Divider(indent: 24, endIndent: 24),
                const SizedBox(height: 16),
                Text(
                  species.description!,
                  // 동화풍 설명 문단은 연필 손글씨 폰트(Gaegu)로 쓰면 길게 읽기 힘들어서
                  // (2026-08-26, 사용자 요청) 원래의 기본 서체(Flutter 기본 Roboto)로 되돌림 —
                  // 나머지 제목/라벨류는 그대로 손글씨 폰트 유지.
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontFamily: 'Roboto', height: 1.5),
                ),
                const SizedBox(height: 16),
                const Divider(indent: 24, endIndent: 24),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.acquisitionHistoryLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final encounter in encounters)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(
                    encounter.tourismSpotTitle ??
                        _formatDate(encounter.hatchedAt),
                  ),
                  subtitle: encounter.tourismSpotTitle == null
                      ? null
                      : Text(_formatDate(encounter.hatchedAt)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
