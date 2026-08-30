import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 파트너 알을 처음 지정할 때, Health Connect 권한/설치 플로우로 넘어가기 전에 보여주는 안내
/// 다이얼로그 — 실기기 확인 결과 예고 없이 곧바로 Play Store의 Health Connect 설치 화면으로
/// 넘어가서 사용자가 당황하는 문제가 있었음(Document/temp.md 참고). location_consent_dialog.dart와
/// 달리 법적 동의가 아니라 순수 안내라 체크박스 없이 확인/취소만 제공.
///
/// 호출부(egg_inventory_screen.dart)가 [DistanceTrackerService.hasPermission]으로 이미 권한이
/// 있는지 먼저 확인해서, 있으면 이 다이얼로그를 아예 건너뛴다 — 이미 허용된 사용자에게 매번 안내를
/// 또 띄울 이유가 없음.
Future<bool> showHealthConnectNoticeDialog(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => const _HealthConnectNoticeDialogContent(),
  );
  return agreed ?? false;
}

class _HealthConnectNoticeDialogContent extends StatelessWidget {
  const _HealthConnectNoticeDialogContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.healthConnectNoticeDialogTitle),
      content: Text(l10n.healthConnectNoticeBodyMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.confirmButton),
        ),
      ],
    );
  }
}
