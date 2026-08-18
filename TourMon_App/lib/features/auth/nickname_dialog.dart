import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 닉네임 입력 다이얼로그(온보딩/수정 공용, `AccountButton`/`MyPageScreen` 둘 다 사용).
///
/// `showDialog`가 반환하는 Future는 `Navigator.pop()`이 호출되는 즉시 완료되는데, 다이얼로그 자체의
/// 닫힘 애니메이션(트랜지션)은 그 뒤로도 잠깐 더 진행됨 — 그래서 `TextEditingController`를 호출부에서
/// 만들어 `await showDialog(...)` 직후(`finally` 등)에 바로 `dispose()`하면, 아직 화면에서 사라지는
/// 애니메이션 중인 `TextField`가 이미 dispose된 컨트롤러를 참조하다가 프레임워크 단 크래시로 이어짐
/// (실기기에서 "A TextEditingController was used after being disposed" → "Duplicate GlobalKeys" →
/// `_dependents.isEmpty` assertion 순으로 재현 확인, 2026-08-18). "완료" 버튼 경로는 그 사이에
/// `upsertProfile` 네트워크 호출이 껴서 애니메이션이 끝날 시간을 우연히 벌어줬을 뿐이라 "취소"/화면
/// 밖 탭처럼 바로 반환되는 경로에서만 실제로 터짐 — 근본 원인은 dismiss 방식이 아니라 컨트롤러
/// 소유권이었음. 그래서 컨트롤러를 이 위젯 자신의 `State.dispose()`가 관리하도록 캡슐화해서
/// Flutter가 실제 언마운트 시점에 맞춰 정리하게 함.
Future<String?> showNicknameDialog(
  BuildContext context, {
  required String initialNickname,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: _NicknameDialogContent(initialNickname: initialNickname),
    ),
  );
}

class _NicknameDialogContent extends StatefulWidget {
  const _NicknameDialogContent({required this.initialNickname});

  final String initialNickname;

  @override
  State<_NicknameDialogContent> createState() => _NicknameDialogContentState();
}

class _NicknameDialogContentState extends State<_NicknameDialogContent> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialNickname);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.nicknameDialogTitle),
      content: TextField(
        controller: _controller,
        maxLength: 30,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.nicknameHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.doneButton),
        ),
      ],
    );
  }
}
