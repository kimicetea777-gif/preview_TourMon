import 'package:flutter/material.dart';

import 'sketch_card_painter.dart';
import 'sketch_theme.dart';

/// FloatingActionButton 대체 — 종이 질감 채우기 + 아이콘(2026-08-26, 지도 화면 스케치 테마).
/// active일 때만 색연필 포인트 컬러로 채워서 "추적 중" 상태를 표현(기존 FAB의 남색/회색 토글과
/// 같은 역할). 테두리는 손그림 흔들리는 잉크선 대신 일반 실선 border로 표시(2026-08-26,
/// 사용자 요청 — MyPageScreen의 Card.outlined 전환과 같은 방향).
class SketchFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final bool active;
  final double size;

  const SketchFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    required this.active,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final fill = active ? SketchTheme.accent : SketchTheme.paper;
    final fg = active ? SketchTheme.paper : SketchTheme.ink;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: fill,
          shape: const CircleBorder(
            side: BorderSide(color: SketchTheme.ink, width: 1.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(child: Icon(icon, color: fg, size: size * 0.46)),
          ),
        ),
      ),
    );
  }
}

/// FilledButton 대체 — 알약 모양 손그림 버튼(재시도/부화 버튼 등에 사용). onPressed가 null이면
/// 비활성 상태로 옅게 표시(부화 버튼의 "부화 중" 로딩 스피너 표시 중 재입력 막기 용도,
/// egg_inventory_screen.dart 참고).
class SketchButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? leading;

  const SketchButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: CustomPaint(
        painter: const SketchCardPainter(
          fillColor: SketchTheme.accent,
          borderColor: SketchTheme.ink,
          radius: 24,
          seed: 8,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: SketchTheme.fontFamily,
                      color: SketchTheme.paper,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
