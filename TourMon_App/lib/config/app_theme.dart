import 'package:flutter/material.dart';

/// 앱 브랜드 컬러 4종(2026-08-18, 사용자 지정) — Neutral이 짙은 남색이라 다크 테마로 가고, 그 위에
/// Primary(밝은 하늘색)가 강조색으로 얹히는 구도. `ColorScheme.fromSeed`로 나머지 톤(container,
/// onXxx, outline 등)은 Material 3가 자동 생성하고, 이 4가지 anchor 색만 그대로 고정.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFFE4F0F6);
  static const Color secondary = Color(0xFF2A3B52);
  static const Color tertiary = Color(0xFF63D2FF);
  static const Color neutral = Color(0xFF0A0D1E);

  static ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          primary: primary,
          secondary: secondary,
          tertiary: tertiary,
          surface: neutral,
        ),
      );
}
