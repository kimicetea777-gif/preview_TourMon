import 'package:flutter/material.dart';

import 'sketch_path.dart';

/// 종이 질감 배경 + 연필로 두 번 겹쳐 그린 듯한 테두리 + 옅게 어긋난 그림자 한 겹을 그리는
/// 페인터. 사각 카드(SketchCard)와 원형 FAB/버튼이 모두 이 하나를 공유(원은 radius를 크게
/// 줘서 sketchRRectPath가 자동으로 원으로 처리, sketch_path.dart 주석 참고).
class SketchCardPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double radius;
  final int seed;

  const SketchCardPainter({
    required this.fillColor,
    required this.borderColor,
    required this.radius,
    this.seed = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = radius.clamp(0, size.shortestSide / 2).toDouble();

    final shadowPath = sketchRRectPath(
      rect.translate(2.5, 3.5),
      r,
      jitter: 1.4,
      seed: seed + 11,
    );
    canvas.drawPath(
      shadowPath,
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );

    final fillPath = sketchRRectPath(rect, r, jitter: 1.1, seed: seed);
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = borderColor;
    canvas.drawPath(
      sketchRRectPath(rect, r, jitter: 1.6, seed: seed + 3),
      borderPaint,
    );
    canvas.drawPath(
      sketchRRectPath(rect, r, jitter: 1.6, seed: seed + 59),
      borderPaint..color = borderColor.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant SketchCardPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.radius != radius ||
      oldDelegate.seed != seed;
}
