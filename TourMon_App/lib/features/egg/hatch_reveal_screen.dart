import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../monster/monster_species.dart';
import '../monster/rarity_colors.dart';

/// 4단계 — 부화 연출. 알 흔들림(전 몬스터 공통, 앱 내장 애니메이션 하나) → 결과 공개(희귀도별
/// 빛 효과) 순서 — init_plan.md 4-3 섹션. 실제 게임 아트/파티클 에셋이 아직 없어서(§5 TBD) 지금은
/// Flutter 기본 애니메이션 API만으로 구현 — 나중에 실제 에셋이 생기면 이 화면 내부만 교체하면 됨.
class HatchRevealScreen extends StatefulWidget {
  final MonsterSpecies species;

  const HatchRevealScreen({super.key, required this.species});

  @override
  State<HatchRevealScreen> createState() => _HatchRevealScreenState();
}

class _HatchRevealScreenState extends State<HatchRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _revealed = false;

  static const _shakeDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _shakeDuration)
      ..forward();
    Future.delayed(_shakeDuration, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(widget.species.rarity);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _revealed ? _buildReveal(color) : _buildShake(),
        ),
      ),
    );
  }

  Widget _buildShake() {
    return AnimatedBuilder(
      key: const ValueKey('shake'),
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = 0.25 * (1 - t) * (((t * 20).floor() % 2 == 0) ? 1 : -1);
        return Transform.rotate(
          angle: angle,
          child: const Icon(Icons.egg, size: 120, color: Colors.white),
        );
      },
    );
  }

  Widget _buildReveal(Color color) {
    return Column(
      key: const ValueKey('reveal'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 60, spreadRadius: 20),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.species.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Icon(Icons.pets, size: 100, color: color),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.species.name,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.species.description ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.confirmButton),
        ),
      ],
    );
  }
}
