import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/app_localizations.dart';
import 'remote_config_service.dart';

/// 설치 빌드가 원격 `minSupportedBuild`보다 낮을 때 `AppGate`가 지도 대신 띄우는 차단 화면.
/// 뒤로가기로 못 빠져나감(`PopScope`) — 유일한 행동은 스토어로 이동해 업데이트하는 것.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: SketchTheme.themeData,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: SketchTheme.paper,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update,
                      size: 72,
                      color: SketchTheme.ink,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.updateRequiredBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    SketchButton(
                      onPressed: () => launchUrl(
                        Uri.parse(RemoteConfigService.instance.updateUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      label: l10n.updateRequiredButton,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
