import 'package:flutter/material.dart';

import '../../audio/sfx.dart';
import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../monster/rarity_colors.dart';
import 'egg_image.dart';
import 'egg_inventory_screen.dart';
import 'user_egg.dart';

/// 앱 최초 실행 온보딩 직후, 웰컴 알([claimWelcomeEggIfNeeded]가 지급한 것)을 알리는 1회성
/// 팝업. 바로 앞의 온보딩 캐러셀과 같은 그림책 테마로 맞춘다(기본 `AlertDialog`는 앱 전역
/// 다크 톤이라 온보딩 → 선물 팝업의 전환이 튐). showDialog의 Overlay는 지도 화면의 지역 Theme
/// 하위 트리가 아니라서 `SketchTheme.themeData`를 다시 감싼다(egg_odds_overview_dialog.dart와
/// 동일 패턴).
///
/// "닫기"는 그냥 닫고, "보관함에서 보기"는 닫은 뒤 [EggInventoryScreen]으로 이동한다(거기서
/// 파트너 지정 → 걷기로 이어지는 핵심 루프 진입).
Future<void> showWelcomeGiftDialog(BuildContext context, UserEgg egg) {
  Sfx.instance.play('welcome_gift');
  return showDialog<void>(
    context: context,
    builder: (context) => _WelcomeGiftDialog(egg: egg),
  );
}

class _WelcomeGiftDialog extends StatelessWidget {
  final UserEgg egg;

  const _WelcomeGiftDialog({required this.egg});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: SketchTheme.themeData,
      // Builder로 한 겹 감싸 이 아래의 Theme.of(context)가 위 SketchTheme를 보도록 함 — showDialog의
      // Overlay는 지도 화면 지역 Theme 밖이라(egg_odds_overview_dialog.dart 주석) 안 감싸면 앱
      // 전역 다크 텍스트 테마가 잡힌다.
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 40,
            ),
            child: SketchCard(
              seed: 4,
              rotationDegrees: -0.8,
              fillColor: SketchTheme.paperLight,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.welcomeGiftTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _EggWithSparkles(rarity: egg.rarity),
                  const SizedBox(height: 12),
                  _RarityPill(rarity: egg.rarity),
                  const SizedBox(height: 12),
                  Text(
                    l10n.welcomeGiftBody,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: SketchTheme.ink,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.welcomeGiftDismissButton),
                      ),
                      const SizedBox(width: 8),
                      SketchButton(
                        label: l10n.welcomeGiftOpenInventoryButton,
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const EggInventoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 알 이미지 + 모서리 반짝임 — 온보딩 4장("부화") 일러스트와 같은 시각 언어.
class _EggWithSparkles extends StatelessWidget {
  final String rarity;

  const _EggWithSparkles({required this.rarity});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        EggImage(rarity: rarity, width: 116),
        const Positioned(
          top: -6,
          right: -2,
          child: Icon(Icons.auto_awesome, size: 30, color: SketchTheme.accent),
        ),
        const Positioned(
          bottom: 2,
          left: -8,
          child: Icon(
            Icons.auto_awesome,
            size: 20,
            color: SketchTheme.accentBlue,
          ),
        ),
      ],
    );
  }
}

/// 등급 배지 — 등급 대표색을 옅게 깐 알약. `_OddsRow`(egg_odds_overview_dialog.dart)의 점+라벨
/// 조합을 축약한 형태.
class _RarityPill extends StatelessWidget {
  final String rarity;

  const _RarityPill({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            rarityLabel(context, rarity),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: SketchTheme.ink,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
