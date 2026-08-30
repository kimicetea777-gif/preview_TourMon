import 'package:flutter/material.dart';

/// "그림책 + 연필 스케치" 테마(2026-08-26, 사용자 요청) — 몬스터 일러스트/동화풍 설명과 어울리는
/// 화면에서만 씀(지도 화면 → 알 보관함 순으로 적용, 2026-08-26). 앱 전역 테마(config/app_theme.dart,
/// 짙은 남색+하늘색 다크 톤)는 그대로 두고, 각 화면 build()에서 Theme 위젯으로 이 테마만 지역
/// 오버라이드(예: MapScreen, EggInventoryScreen — 두 화면 모두 Scaffold 전체를 Theme(data:
/// SketchTheme.themeData, ...)로 감쌈). 화면에서 Navigator.push로 더 들어가는 하위 화면(부화
/// 연출 등)이나 showModalBottomSheet/Dialog는 Overlay가 이 지역 Theme의 하위 트리가 아니라서
/// 자동으로 적용되지 않음 — 필요하면 그 화면에도 동일하게 Theme으로 개별 감싸야 함.
class SketchTheme {
  SketchTheme._();

  static const String fontFamily = 'Gaegu';

  // 종이 질감의 크림색 계열 + 색연필 포인트 컬러.
  static const Color paper = Color(0xFFFBF3DF);
  static const Color paperLight = Color(0xFFFFFCF2);
  static const Color paperDark = Color(0xFFF0E4C2);
  static const Color ink = Color(0xFF3C3324);
  static const Color accent = Color(0xFFE0793F);
  static const Color accentBlue = Color(0xFF4E7CA6);
  static const Color accentGreen = Color(0xFF6E9459);
  // 크림색 종이 위에서도 읽히는 따뜻한 겨자/골든로드 계열 노랑 — 알 획득 반경 원에 사용.
  static const Color accentYellow = Color(0xFFE6B23F);

  static ThemeData get themeData {
    final base = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        primary: accent,
        secondary: accentBlue,
        surface: paper,
      ),
      iconTheme: const IconThemeData(color: ink),
      dividerColor: ink.withValues(alpha: 0.2),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: ink,
        displayColor: ink,
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: paper,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
    );
  }
}
