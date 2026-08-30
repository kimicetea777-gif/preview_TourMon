import 'dart:math';

import 'package:flutter/material.dart';

import 'sketch_card_painter.dart';
import 'sketch_theme.dart';

/// Card 대체 — 손그림 종이 카드처럼 보이는 컨테이너(2026-08-26, 지도 화면 스케치 테마).
/// onTap을 주면 카드 전체가 InkWell(파문은 사각형이 아니라 카드 radius를 따름).
class SketchCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? fillColor;
  final Color? borderColor;
  final double rotationDegrees;
  final int seed;

  const SketchCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 16,
    this.padding = const EdgeInsets.all(10),
    this.fillColor,
    this.borderColor,
    this.rotationDegrees = 0,
    this.seed = 1,
  });

  @override
  Widget build(BuildContext context) {
    final fill = fillColor ?? SketchTheme.paper;
    final border = borderColor ?? SketchTheme.ink;

    final content = CustomPaint(
      painter: SketchCardPainter(
        fillColor: fill,
        borderColor: border,
        radius: radius,
        seed: seed,
      ),
      child: ClipRRect(
        // 카드 안에서 배경색이 다른 구간(예: EggInventoryScreen 알 카드 상단 이미지 영역)을 써도
        // 흔들리는 잉크 테두리 바깥으로 각진 모서리가 삐져나오지 않도록 명목상의(흔들리기 전)
        // 둥근 사각형으로 클리핑.
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    if (rotationDegrees == 0) return content;
    return Transform.rotate(angle: rotationDegrees * pi / 180, child: content);
  }
}
