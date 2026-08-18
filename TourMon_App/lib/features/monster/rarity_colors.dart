import 'package:flutter/material.dart';

/// 희귀도별 대표 색상 — 부화 리빌 연출(`HatchRevealScreen`)과 도감 화면에서 공용으로 사용.
Color rarityColor(String rarity) {
  switch (rarity) {
    case 'rare':
      return const Color(0xFF8B5CF6);
    case 'epic':
      return const Color(0xFFF97316);
    case 'legendary':
      return const Color(0xFFFACC15);
    case 'common':
    default:
      return const Color(0xFF60A5FA);
  }
}
