import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../auth/auth_session.dart';
import '../monster/monster_config_api.dart';
import '../monster/monster_determination.dart';
import '../monster/rarity_colors.dart';
import 'distance_format.dart';
import 'egg_image.dart';
import 'user_egg.dart';

const _rarityOrder = ['common', 'rare', 'epic', 'legendary'];

/// 알 카드의 정보 버튼 → 목표 거리 + 부화 시 몬스터 등급별 확률을 보여주는 바텀시트
/// (Document/temp.md 참고). 확률은 `monsterRarityProbabilities()`로 실제 `determineMonster()`
/// 계산을 그대로 재현 — 꾸며낸 수치가 아니라 실제 부화 로직과 항상 일치.
class EggTypeInfoSheet extends StatefulWidget {
  final UserEgg egg;

  const EggTypeInfoSheet({super.key, required this.egg});

  @override
  State<EggTypeInfoSheet> createState() => _EggTypeInfoSheetState();
}

class _EggTypeInfoSheetState extends State<EggTypeInfoSheet> {
  final _monsterConfigApi = const MonsterConfigApi();
  Future<Map<String, double>>? _probabilitiesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // locale이 필요해 context 의존적 — build()마다 새로 만들면 FutureBuilder가 매번 로딩으로
    // 돌아가므로 한 번만 만들어서 재사용.
    _probabilitiesFuture ??= _load();
  }

  Future<Map<String, double>> _load() async {
    final config = await _monsterConfigApi.fetchConfig(
      locale: apiLocaleOf(context),
    );
    return monsterRarityProbabilities(widget.egg.rarity, config);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final egg = widget.egg;
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EggImage(rarity: egg.rarity, width: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        egg.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        rarityLabel(context, egg.rarity),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoRow(
              label: l10n.eggInfoTargetDistanceLabel,
              value: '${formatKm(egg.targetDistanceMeters)}km',
            ),
            if (!context.watch<AuthSession>().isLoggedIn) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_bottom,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.eggInfoGuestShelfLifeNote(
                        GameConfig.guestEggShelfLife.inDays,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(
              l10n.eggInfoHatchOddsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            FutureBuilder<Map<String, double>>(
              future: _probabilitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
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
                final probabilities = snapshot.data!;
                // 알 등급 이상만 — 부화 로직상 낮은 등급 몬스터는 확률 0이라 표시해도 "0%"만 나옴.
                final startIndex = _rarityOrder.indexOf(egg.rarity);
                final shownRarities = startIndex >= 0
                    ? _rarityOrder.sublist(startIndex)
                    : _rarityOrder;
                return Column(
                  children: [
                    for (final rarity in shownRarities)
                      _OddsRow(
                        color: rarityColor(rarity),
                        label: rarityLabel(context, rarity),
                        percent: probabilities[rarity] ?? 0,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
    // showModalBottomSheet의 Overlay는 알 보관함 화면의 지역 SketchTheme 서브트리가 아니라서
    // 그림책 테마가 자동 적용되지 않음 — 여기서 다시 감싼다(egg_odds_overview_dialog.dart와 동일).
    // 호출부(egg_inventory_screen.dart)가 시트 배경도 SketchTheme.paperLight로 지정하므로,
    // 이 Theme으로 본문 텍스트/아이콘이 크림색 위에서 읽히는 잉크색이 된다.
    return Theme(data: SketchTheme.themeData, child: content);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
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
