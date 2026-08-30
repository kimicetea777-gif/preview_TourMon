import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../egg/migration_service.dart';
import '../mypage/my_page_screen.dart';
import 'auth_session.dart';
import 'authorized_api_client.dart';
import 'nickname_dialog.dart';

/// 6단계 Phase 2 — 지도 화면 AppBar의 계정 진입점 (init_plan.md 4-1 "게스트 → 회원가입").
/// 로그인 여부와 무관하게 항상 마이페이지(`MyPageScreen`)로 이동 — 게스트 상태여도 언어 선택/
/// 관광지 재동기화 같은 로그인 무관 기능을 쓸 수 있어야 해서(2026-08-26, 사용자 리포트: 예전엔
/// 게스트가 이 버튼을 누르면 곧장 로그인 브라우저가 떠서 그 기능들에 접근할 방법이 없었음).
/// 로그인 자체는 `MyPageScreen` 안의 "로그인" 버튼을 눌러야만 시작됨(온보딩이 안 끝난 상태로
/// 남아있었으면 닉네임 입력으로 이어서 보냄 — 로그인 직후 흐름이 중간에 끊겨도 다시 들어올
/// 방법이 있어야 함).
///
/// 게스트 모드는 그대로 완전히 동작(CLAUDE.md "게스트 모드로 핵심 루프 먼저") — 로그인은 선택적
/// 기능일 뿐, 안 해도 지도/알/부화/도감은 지금까지와 동일하게 동작함.
class AccountButton extends StatefulWidget {
  const AccountButton({super.key});

  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  bool _busy = false;

  Future<void> _onPressed(AuthSession session) async {
    setState(() => _busy = true);
    try {
      if (session.isLoggedIn) {
        await _openMyPage(session);
      } else {
        await _openMyPageAsGuest();
      }
    } catch (e) {
      if (mounted) _showSnackBar(AppLocalizations.of(context)!.genericErrorMessage('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 게스트 상태 진입 — fetchProfile 등 인증이 필요한 API 호출 없이 곧장 마이페이지로 이동.
  /// 로그인 자체는 MyPageScreen 안의 로그인 버튼(그 화면의 _login, AuthCancelledException 처리도
  /// 거기서 함)이 담당.
  Future<void> _openMyPageAsGuest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const MyPageScreen(initialProfile: null, profileFetchFailed: false),
      ),
    );
  }

  /// 다이얼로그 자체는 `nickname_dialog.dart`(컨트롤러 dispose 타이밍 버그 수정 내역 참고) 공용 위젯.
  Future<void> _showNicknameDialog(AuthApi api, AuthorizedApiClient client) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final nickname = await showNicknameDialog(context, initialNickname: '');
      if (nickname == null) return;
      if (nickname.isEmpty) {
        if (mounted) _showSnackBar(l10n.nicknameEmptyError);
        return;
      }

      final profile = await api.upsertProfile(nickname);
      if (mounted) _showSnackBar(l10n.welcomeMessage(profile.nickname));
      // 로그인+닉네임 확정 직후가 게스트→회원 마이그레이션 트리거 시점(Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
      await syncGuestDataWithServer(client);
    } catch (e) {
      if (mounted) _showSnackBar(l10n.nicknameSaveError('$e'));
    }
  }

  /// 로그인 상태에서 계정 아이콘을 눌렀을 때 진입점 — 마이페이지 화면으로 이동(닉네임 확인/수정,
  /// 도감/알 요약, 로그아웃은 전부 `MyPageScreen`이 담당, `Document/plan/later.md` "마이페이지" 참고).
  Future<void> _openMyPage(AuthSession session) async {
    final client = AuthorizedApiClient(session, locale: apiLocaleOf(context));
    final api = AuthApi(client);
    UserProfile? profile;
    // fetchProfile()은 "서버가 명확히 미온보딩이라고 답함"(404 → null)과 "요청 자체가 실패함"
    // (네트워크 등 → 예외)을 구분해서 알려줌 — 이 둘을 같은 걸로 취급하면, 이미 닉네임을 설정한
    // 사용자가 오프라인 상태에서 계정 버튼을 눌렀을 때 엉뚱하게 닉네임 재입력 다이얼로그가 뜨게 됨.
    var fetchFailed = false;
    try {
      profile = await api.fetchProfile();
    } catch (e) {
      developer.log('마이페이지 진입 시 fetchProfile 실패: $e', name: 'AccountButton');
      fetchFailed = true;
    }
    if (!mounted) return;

    if (profile == null && !fetchFailed) {
      // 로그인은 됐지만 온보딩(닉네임 설정)이 끝나지 않은 상태 — 예: 로그인 직후 앱이 죽었거나
      // 네트워크가 끊겨서 닉네임 저장을 못 마친 경우. 다시 닉네임 입력으로 이어서 완료하게 함.
      await _showNicknameDialog(api, client);
      return;
    }
    // 기존 로그인 사용자(profile != null)는 여기서 syncGuestDataWithServer를 다시 안 돌림 —
    // 마이그레이션/복구는 이미 로그인 시점(MyPageScreen._login/_showNicknameDialog)에 한 번
    // 실행됐고, 마이페이지를 여닫을 때마다 서버 전체 알/도감을 다시 fetch하는 게 체감 로딩을
    // 불필요하게 늦추고 있었음(사용자 피드백, 2026-08-19). 재설치 등으로 마이그레이션 플래그
    // 자체가 없는 예외 케이스는 다음 로그인 때 자연히 다시 실행되므로 여기서 구제할 필요 없음.

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MyPageScreen(initialProfile: profile, profileFetchFailed: fetchFailed),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    // _busy(위젯 로컬)만으로는 위젯이 리빌드/재생성될 때 초기화돼서 진짜 겹침을 못 막음 —
    // session.isAuthenticating(싱글턴)도 같이 봐야 위젯이 새로 만들어져도 버튼이 다시 눌리지 않음.
    final busy = _busy || session.isAuthenticating;
    return IconButton(
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(session.isLoggedIn ? Icons.person : Icons.person_outline),
      // 로그인 여부와 무관하게 항상 마이페이지로 이동하므로(위 클래스 doc 참고) 툴팁도 상태와
      // 무관하게 통일 — "로그인"이라고 하면 눌렀을 때 곧장 로그인되는 것처럼 오해할 수 있음.
      tooltip: AppLocalizations.of(context)!.myPageTitle,
      onPressed: busy ? null : () => _onPressed(session),
    );
  }
}
