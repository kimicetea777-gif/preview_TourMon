import 'package:flutter/material.dart';

import '../../data/app_settings_repository.dart';
import '../../l10n/app_localizations.dart';

const _consentVersionKey = 'location_consent_version';

/// 고지 문구가 바뀌면 이 값을 올려서 저장된 버전과 달라지게 함 — [ensureLocationConsent]가 그
/// 차이를 보고 재동의를 다시 요구함(이용약관/개인정보처리방침 쪽 AS `TermService` 재동의와 동일한
/// 감각, Document/temp.md §3/§4 참고).
///
/// v2(2026-08-30) — 거리 측정 이중화(Document/temp.md)로 위치정보 이용 목적에 "걸은 거리 측정"이
/// 추가되고 "집계 거리 값은 저장"으로 바뀌어 [locationConsentBodyMessage] 고지 문구가 실질
/// 변경됨. 기존 동의자도 다시 동의를 받도록 버전 상향.
///
/// v3(2026-08-31) — 게스트 전용 출시(Document/temp.md "게스트 전용 출시")로 위치정보가 서버로
/// 전송되지 않고 전적으로 기기 내에서만 처리됨. [locationConsentBodyMessage]를 "서버 전송·저장
/// 없음, 기기 내 처리"로 고쳐 개인정보처리방침 제2조와 일치시킴. 실질 변경이라 버전 상향.
const _currentConsentVersion = '3';

/// 위치정보 수집·이용 동의 + 만 14세 이상 확인을 게이트하는 진입점.
///
/// 게스트도 로그인 없이 바로 위치정보를 쓰는 지점(지도 "현재 위치로 이동", 알 획득)이 있어 AS의
/// 로그인 시점 약관 동의 흐름으로는 커버가 안 됨 — 그래서 TourMon이 Flutter 안에서 직접 이 동의를
/// 받음(Document/temp.md §3). 이미 현재 버전으로 동의한 적 있으면 다이얼로그 없이 바로 통과.
Future<bool> ensureLocationConsent(BuildContext context) async {
  const settings = AppSettingsRepository();
  final storedVersion = await settings.getValue(_consentVersionKey);
  if (storedVersion == _currentConsentVersion) return true;

  if (!context.mounted) return false;
  final agreed = await showLocationConsentDialog(context);
  if (agreed != true) return false;

  await settings.setValue(_consentVersionKey, _currentConsentVersion);
  return true;
}

/// 다이얼로그를 띄우지 않고 "현재 버전 동의가 이미 저장돼 있는지"만 확인한다 — 지도 화면이 앱
/// 시작 시 OS 권한 팝업을 띄우지 않고 조용히 위치 추적을 재개할지 판단할 때 씀([ensureLocationConsent]와
/// 달리 부수효과 없음).
Future<bool> hasStoredLocationConsent() async {
  const settings = AppSettingsRepository();
  final storedVersion = await settings.getValue(_consentVersionKey);
  return storedVersion == _currentConsentVersion;
}

Future<bool?> showLocationConsentDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const PopScope(
      canPop: false,
      child: _LocationConsentDialogContent(),
    ),
  );
}

class _LocationConsentDialogContent extends StatefulWidget {
  const _LocationConsentDialogContent();

  @override
  State<_LocationConsentDialogContent> createState() =>
      _LocationConsentDialogContentState();
}

class _LocationConsentDialogContentState
    extends State<_LocationConsentDialogContent> {
  bool _locationAgreed = false;
  bool _ageConfirmed = false;

  bool get _canConfirm => _locationAgreed && _ageConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.locationConsentDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.locationConsentBodyMessage),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _locationAgreed,
              onChanged: (value) =>
                  setState(() => _locationAgreed = value ?? false),
              title: Text(l10n.locationConsentAgreeCheckboxLabel),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _ageConfirmed,
              onChanged: (value) =>
                  setState(() => _ageConfirmed = value ?? false),
              title: Text(l10n.ageConsentCheckboxLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.confirmButton),
        ),
      ],
    );
  }
}
