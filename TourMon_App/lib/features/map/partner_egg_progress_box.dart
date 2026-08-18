import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../data/daily_steps_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../egg/egg_image.dart';
import '../egg/egg_repository.dart';
import '../egg/user_egg.dart';

/// 지도 화면 좌상단 파트너 알 진행도 박스(Document/temp.md 참고) — 순수 읽기 전용 요약. 알/빈
/// 슬롯 행을 포함해 박스 어디를 탭해도 접기/펼치기만 토글될 뿐 다른 화면으로 이동하지 않음
/// (2026-08-18, 사용자 요청으로 행 탭 시 `EggInventoryScreen` 이동을 제거 — 알 보관함 진입점은
/// 이제 `QuickActionsBox` 하나로 통일).
class PartnerEggProgressBox extends StatefulWidget {
  const PartnerEggProgressBox({super.key});

  @override
  State<PartnerEggProgressBox> createState() => _PartnerEggProgressBoxState();
}

class _PartnerEggProgressBoxState extends State<PartnerEggProgressBox> {
  final _eggRepository = const EggRepository();
  final _dailyStepsRepository = const DailyStepsRepository();

  bool _expanded = true;
  List<UserEgg> _partnerEggs = [];
  int _todaySteps = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // egg_inventory_screen.dart와 동일한 패턴 — 로컬 sqlite만 읽는 화면이라 짧게 잡아도 비용
    // 부담 없음(GameConfig.eggInventoryRefreshInterval 주석 참고). 새 아키텍처(리스너/스트림)
    // 없이 이 기존 폴링 패턴을 그대로 재사용.
    _refreshTimer = Timer.periodic(GameConfig.eggInventoryRefreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final eggs = await _eggRepository.getUnhatchedEggs();
    final steps = await _dailyStepsRepository.getTodaySteps();
    if (!mounted) return;
    setState(() {
      _partnerEggs = eggs.where((egg) => egg.isPartner).toList();
      _todaySteps = steps;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 전용 접기/펼치기 아이콘 없이 박스 전체(알/빈 슬롯 행 포함)를 탭 대상으로 씀 — 별도
    // 내비게이션이 없어졌으니 안에 중첩 InkWell을 둘 이유도 없어져서 이 InkWell 하나로 충분.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Tooltip(
          message: _expanded
              ? l10n.collapsePartnerEggBoxTooltip
              : l10n.expandPartnerEggBoxTooltip,
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topLeft,
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const _CollapsedContent(),
            secondChild: _ExpandedContent(
              partnerEggs: _partnerEggs,
              todaySteps: _todaySteps,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Icon(Icons.egg_outlined),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final List<UserEgg> partnerEggs;
  final int todaySteps;

  const _ExpandedContent({
    required this.partnerEggs,
    required this.todaySteps,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calories = (todaySteps * GameConfig.caloriesPerStep).round();
    return SizedBox(
      width: 160,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < GameConfig.maxPartnerEggs; i++)
              _PartnerSlotRow(egg: i < partnerEggs.length ? partnerEggs[i] : null),
            const Divider(height: 16),
            // 왼쪽 끝 걸음 수 / 오른쪽 끝 칼로리 — 각각 아이콘으로 구분(2026-08-18, 사용자 요청).
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconStat(icon: Icons.directions_walk, label: '$todaySteps'),
                _IconStat(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  label: l10n.todayCaloriesLabel(calories),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘 걸음 수/칼로리 한 줄의 아이콘+숫자 조각 — 두 조각을 좌우 끝에 배치하는 용도.
class _IconStat extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;

  const _IconStat({required this.icon, this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PartnerSlotRow extends StatelessWidget {
  final UserEgg? egg;

  const _PartnerSlotRow({required this.egg});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final egg = this.egg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: egg == null
                  ? const _EmptyPartnerSlotIcon()
                  : EggImage(rarity: egg.rarity, width: 24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: egg == null
                  ? [
                      Text(
                        l10n.emptyPartnerSlotLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]
                  : [
                      Text(
                        rarityLabel(context, egg.rarity),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        l10n.partnerEggStepsLabel(egg.stepsAccumulated, egg.targetSteps),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 빈 파트너 슬롯 표시 — '+' 대신 원형 빗금(diagonal hatch) 아이콘(2026-08-18 결정,
/// Document/temp.md 참고). 파트너로 지정된 알이 2개 미만이면(보유 알이 0개인 경우 포함) 이 아이콘.
class _EmptyPartnerSlotIcon extends StatelessWidget {
  const _EmptyPartnerSlotIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _DiagonalHatchCirclePainter(
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _DiagonalHatchCirclePainter extends CustomPainter {
  final Color color;

  const _DiagonalHatchCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final hatchPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const gap = 5.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatchPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalHatchCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
