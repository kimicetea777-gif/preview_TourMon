import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 등급별 알 스케치 이미지(`assets/eggs/{rarity}.svg`, Document/temp.md "알 이미지" 참고) —
/// 기존 `Icon(Icons.egg_outlined)` 플레이스홀더를 대체. 원본 SVG의 가로:세로 비율(120:140)에 맞춰
/// [width]만 받고 높이는 자동 계산 — 다른 값을 넣으면 이미지가 눌리거나 늘어남.
class EggImage extends StatelessWidget {
  final String rarity;
  final double width;

  const EggImage({super.key, required this.rarity, this.width = 32});

  static const _knownRarities = {'common', 'rare', 'epic', 'legendary'};

  @override
  Widget build(BuildContext context) {
    final asset = _knownRarities.contains(rarity) ? rarity : 'common';
    return SvgPicture.asset(
      'assets/eggs/$asset.svg',
      width: width,
      height: width * 140 / 120,
    );
  }
}
