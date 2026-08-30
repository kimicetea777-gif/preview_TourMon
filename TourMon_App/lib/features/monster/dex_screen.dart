import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import 'dex_detail_screen.dart';
import 'monster_config_api.dart';
import 'monster_repository.dart';
import 'monster_species.dart';
import 'rarity_colors.dart';
import 'user_monster.dart';

/// 5단계 — 도감(Dokedex) 목록 화면. 서버 `/api/monsters/config`의 전체 종 목록(dex_number 순)에
/// 로컬 sqlite `user_monsters`를 종별로 매칭해서, 못 잡은 종은 실루엣+'???'로 잠긴 채 보여준다
/// (포켓몬고류 "수집 목표"형 도감 — init_plan.md 4-4 섹션).
class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  final _monsterConfigApi = const MonsterConfigApi();
  final _monsterRepository = const MonsterRepository();

  List<MonsterSpecies> _species = [];
  Map<int, List<UserMonster>> _grouped = {};
  bool _loading = true;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grouped = await _monsterRepository.getGroupedBySpeciesId();
      if (!mounted) return;
      try {
        final config = await _monsterConfigApi.fetchConfig(
          locale: apiLocaleOf(context),
        );
        if (!mounted) return;
        final species = [...config.species]
          ..sort((a, b) => a.dexNumber.compareTo(b.dexNumber));
        setState(() {
          _species = species;
          _grouped = grouped;
          _offline = false;
          _loading = false;
        });
      } catch (_) {
        // 서버 설정 데이터 조회 실패(오프라인 등) — 전체 종 목록/잠금 표시는 못 하지만, 이미 잡은
        // 몬스터는 부화 시점 로컬 스냅샷(UserMonster)만으로도 표시 가능하므로 그거라도 보여준다.
        if (!mounted) return;
        final species =
            grouped.values
                .map((encounters) => encounters.first.toSpecies())
                .toList()
              ..sort((a, b) => a.dexNumber.compareTo(b.dexNumber));
        setState(() {
          _species = species;
          _grouped = grouped;
          _offline = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.dexLoadFailedMessage('$e');
        _loading = false;
      });
    }
  }

  void _onSpeciesTapped(MonsterSpecies species) {
    final encounters = _grouped[species.id];
    if (encounters == null || encounters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.notDiscoveredMessage),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DexDetailScreen(species: species, encounters: encounters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final caughtCount = _grouped.length;
    // 지도/알 보관함과 같은 그림책+연필 스케치 테마를 이 화면 서브트리에만 지역 적용
    // (2026-08-26, 사용자 요청 — config/sketch/sketch_theme.dart 주석 참고).
    return Theme(
      data: SketchTheme.themeData,
      // Builder로 새 context를 얻어야 함 — 아래 offline 배너의 Theme.of(context)가 이 Theme
      // 바깥(상위 라우트)의 앱 전역 테마를 잡지 않도록(dex_detail_screen.dart와 같은 이유,
      // 2026-08-26 실기기 확인).
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(l10n.dexTitle)),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        SketchButton(onPressed: _load, label: l10n.retryButton),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _DexProgressBanner(
                      caughtCount: caughtCount,
                      totalCount: _species.length,
                      offline: _offline,
                    ),
                    if (_offline)
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.errorContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          l10n.offlineBannerMessage,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _species.isEmpty
                            ? ListView(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(l10n.noMonstersMessage),
                                    ),
                                  ),
                                ],
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.8,
                                    ),
                                itemCount: _species.length,
                                itemBuilder: (context, index) {
                                  final species = _species[index];
                                  final encounters = _grouped[species.id];
                                  return _DexEntryCard(
                                    species: species,
                                    count: encounters?.length ?? 0,
                                    onTap: () => _onSpeciesTapped(species),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 그리드 상단 "n/total COLLECTED" 진행도 배너. 오프라인일 땐 전체 종 목록을 정확히
/// 모르므로(로컬에만 있는 그룹 목록으로 대체) 분수/진행바 대신 발견 수만 보여준다.
class _DexProgressBanner extends StatelessWidget {
  final int caughtCount;
  final int totalCount;
  final bool offline;

  const _DexProgressBanner({
    required this.caughtCount,
    required this.totalCount,
    required this.offline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = totalCount == 0 ? 0.0 : caughtCount / totalCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: SketchTheme.paperDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offline
                ? l10n.dexOfflineCountLabel(totalCount)
                : l10n.dexProgressLabel(caughtCount, totalCount),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          if (!offline) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: SketchTheme.paper,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DexEntryCard extends StatelessWidget {
  final MonsterSpecies species;
  final int count;
  final VoidCallback onTap;

  const _DexEntryCard({
    required this.species,
    required this.count,
    required this.onTap,
  });

  bool get _caught => count > 0;

  @override
  Widget build(BuildContext context) {
    return SketchCard(
      onTap: onTap,
      radius: 12,
      padding: EdgeInsets.zero,
      // 못 잡은 종은 살짝 어두운 종이 톤(paperDark)으로 그늘지게, 잡은 종은 밝은 종이 톤
      // (paperLight)으로 — 알 카드와 같은 명암 규칙(2026-08-26, 사용자 요청).
      fillColor: _caught ? SketchTheme.paperLight : SketchTheme.paperDark,
      seed: species.id,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // stretch 없이는 Column 기본 정렬(center)이 아래 Padding을 텍스트 너비만큼만 감싸서
        // 카드 중앙에 두므로, 안쪽 Column의 start 정렬이 무의미해짐(실기기 확인, Document/temp.md
        // "도감 번호/이름 왼쪽 정렬" 참고) — 카드 전체 너비로 늘려야 안쪽 start 정렬이 실제로 먹힘.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: 6,
                  child: _RarityDot(color: rarityColor(species.rarity)),
                ),
                Center(
                  child: _caught
                      ? CachedNetworkImage(
                          imageUrl: species.imageUrl,
                          width: 56,
                          height: 56,
                          memCacheWidth: 112,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => Icon(
                            Icons.pets,
                            size: 40,
                            color: rarityColor(species.rarity),
                          ),
                        )
                      // 미발견 종 — 실루엣 '형태'는 계속 물음표로 가리되, 희귀도 색만 입힌다
                      // (2026-08-29 결정: 종별 희귀도는 고정 속성이라 스포일러가 아니고,
                      // "전설 몇 종 남았는지"가 수집 동기를 키움 — init_plan.md 4-4 · 5_도감.md).
                      : Icon(
                          Icons.question_mark,
                          size: 32,
                          color: rarityColor(species.rarity),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${species.dexNumber.toString().padLeft(3, '0')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _caught
                      ? species.name
                      : AppLocalizations.of(context)!.unknownSpeciesLabel,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 희귀도를 색상으로 표시하는 카드 좌상단 동그라미. 미발견 종도 희귀도 색은 그대로
/// 노출한다 — 종별 희귀도는 고정 속성(`monster_species.rarity` NOT NULL)이라 스포일러가
/// 아니고, "전설 몇 종 남았는지"를 보여주는 게 수집 동기를 키우기 때문(2026-08-29 결정).
/// 단, 실루엣 '형태'(생김새)는 부화 전까지 계속 물음표로 가린다 — 색만 노출.
class _RarityDot extends StatelessWidget {
  final Color color;

  const _RarityDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
    );
  }
}
