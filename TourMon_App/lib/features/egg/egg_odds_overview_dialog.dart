import 'package:flutter/material.dart';

import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../monster/monster_config_api.dart';
import '../monster/monster_determination.dart';
import '../monster/rarity_colors.dart';
import 'egg_image.dart';

// 낮은 → 높은 등급 순. 알 등급별 섹션은 "그 알 등급 이상"의 몬스터만 보여주므로
// 이 순서에서의 인덱스로 잘라낸다(부화 로직도 gap < 0이면 배율 0이라 실제로 안 나옴).
const _rarityOrder = ['common', 'rare', 'epic', 'legendary'];

/// 알 보관함 AppBar의 확률 버튼 → 보유 여부와 상관없이 "알 등급별로 부화 시 나올 수 있는
/// 몬스터 등급 확률"을 한 번에 보여주는 그림책 테마 팝업. 특정 알 하나에 대한 정보는
/// `egg_type_info_sheet.dart`(알 카드의 info 버튼) 참고. 확률은 `monsterRarityProbabilities()`로
/// 실제 `determineMonster()` 계산을 그대로 재현 — 꾸며낸 수치가 아님.
Future<void> showEggOddsOverviewDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _EggOddsOverviewDialog(),
  );
}

class _EggOddsOverviewDialog extends StatefulWidget {
  const _EggOddsOverviewDialog();

  @override
  State<_EggOddsOverviewDialog> createState() => _EggOddsOverviewDialogState();
}

class _EggOddsOverviewDialogState extends State<_EggOddsOverviewDialog> {
  final _monsterConfigApi = const MonsterConfigApi();
  Future<Map<String, Map<String, double>>>? _oddsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // locale이 필요해 context 의존적 — build()마다 새로 만들면 FutureBuilder가 매번 로딩으로
    // 돌아가므로 한 번만 만들어서 재사용(egg_type_info_sheet.dart와 동일).
    _oddsFuture ??= _load();
  }

  Future<Map<String, Map<String, double>>> _load() async {
    final config = await _monsterConfigApi.fetchConfig(
      locale: apiLocaleOf(context),
    );
    return {
      for (final eggRarity in _rarityOrder)
        eggRarity: monsterRarityProbabilities(eggRarity, config),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // showDialog의 Overlay는 알 보관함 화면의 지역 Theme 하위 트리가 아니라서 그림책 테마가
    // 자동 적용되지 않음 — 여기서 다시 감싼다(config/sketch/sketch_theme.dart 주석 참고).
    return Theme(
      data: SketchTheme.themeData,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: SketchCard(
          fillColor: SketchTheme.paperLight,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eggOddsOverviewTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FutureBuilder<Map<String, Map<String, double>>>(
                    future: _oddsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.eggInfoLoadFailedMessage('${snapshot.error}'),
                          ),
                        );
                      }
                      final oddsByEgg = snapshot.data!;
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _rarityOrder.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  color: SketchTheme.paperDark,
                                  thickness: 1.5,
                                  height: 1.5,
                                ),
                              _EggOddsSection(
                                eggRarity: _rarityOrder[i],
                                probabilities:
                                    oddsByEgg[_rarityOrder[i]] ?? const {},
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.confirmButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EggOddsSection extends StatelessWidget {
  final String eggRarity;
  final Map<String, double> probabilities;

  const _EggOddsSection({required this.eggRarity, required this.probabilities});

  @override
  Widget build(BuildContext context) {
    // 알 등급 이상만 — 부화 로직상 낮은 등급은 확률 0이라 표시해도 "0%"만 나옴.
    final startIndex = _rarityOrder.indexOf(eggRarity);
    final shownRarities = _rarityOrder.sublist(startIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EggImage(rarity: eggRarity, width: 28),
              const SizedBox(width: 8),
              Text(
                rarityLabel(context, eggRarity),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final monsterRarity in shownRarities)
            _OddsRow(
              color: rarityColor(monsterRarity),
              label: rarityLabel(context, monsterRarity),
              percent: probabilities[monsterRarity] ?? 0,
            ),
        ],
      ),
    );
  }
}

class _OddsRow extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;

  const _OddsRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('${percent.round()}%'),
        ],
      ),
    );
  }
}
