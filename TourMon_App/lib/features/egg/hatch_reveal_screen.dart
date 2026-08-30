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
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _revealed ? _buildReveal(color) : _buildShake(),
          ),
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
    // 설명(monster_species.description)이 길면(문단 여러 개짜리 종도 있음) Column이 화면
    // 높이를 넘겨 RenderFlex 오버플로가 났었음 — 스크롤 뷰로 감싸서 길면 스크롤, 짧으면
    // Center가 그대로 세로 가운데 정렬(SingleChildScrollView는 내용이 뷰포트보다 작으면 내용
    // 높이만 차지함).
    return SingleChildScrollView(
      key: const ValueKey('reveal'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 등급별 발광 효과는 몬스터 뒤에 깔리는 원형 후광으로만 쓰고, 몬스터 이미지 자체는
                // 잘라내지 않음 — 원래는 ClipOval로 이미지를 원 안에 가뒀는데, 정사각형 아트의
                // 모서리(팔다리/꼬리 등)가 잘려 보이는 문제가 있었음.
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 60, spreadRadius: 20),
                    ],
                  ),
                ),
                // 부화 연출은 움직이는 아트(animationUrl)를 우선 사용(2026-08-26 사용자 결정,
                // Document/temp.md 참고) — 없으면(구버전 종 등) 정적 imageUrl로 폴백.
                CachedNetworkImage(
                  imageUrl: widget.species.animationUrl ?? widget.species.imageUrl,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, error) => Icon(Icons.pets, size: 100, color: color),
                ),
              ],
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
      ),
    );
  }
}
