import 'dart:math';

import 'package:flutter/material.dart';

/// 반듯한 사각형/원 Path를 손으로 그린 듯 살짝 흔들리게 재샘플링 — 연필 스케치 느낌의 모든
/// 위젯(SketchCardPainter 등)이 공유하는 핵심 유틸. RRect의 radius를 도형의 반폭/반높이
/// 이상으로 주면 Flutter가 알아서 원으로 clamp하므로, 원형(FAB 등)도 이 함수 하나로 그림.
Path sketchRRectPath(
  Rect rect,
  double radius, {
  double jitter = 1.2,
  double step = 7,
  int seed = 1,
}) {
  final base = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  final rnd = Random(seed);
  final points = <Offset>[];
  for (final metric in base.computeMetrics()) {
    final len = metric.length;
    if (len <= 0) continue;
    var d = 0.0;
    while (d < len) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) {
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final j = (rnd.nextDouble() - 0.5) * 2 * jitter;
        points.add(tangent.position + normal * j);
      }
      d += step;
    }
  }
  if (points.length < 3) return base;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    final mid = Offset.lerp(prev, curr, 0.5)!;
    path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}
