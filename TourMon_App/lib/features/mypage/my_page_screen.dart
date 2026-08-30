import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../config/auth_config.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../data/tourism_spot_repository.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/locale_controller.dart';
import '../../root_messenger.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../auth/nickname_dialog.dart';
import '../egg/migration_service.dart';
import '../onboarding/onboarding_screen.dart';

/// 마이페이지 — 프로필(닉네임 확인/수정 + 로그인/로그아웃) + 언어/관광지 재동기화.
/// `AccountButton`이 로그인 상태에서 눌렸을 때 이 화면으로 진입(`Document/plan/later.md`
/// "마이페이지 — 걸음수 통계" 참고 — 거리 통계는 별도 인프라(daily_distance)가 필요해서 이
/// 최초 버전엔 없고 나중에 이 화면에 추가될 예정).
///
/// 도감/알 보관함 요약 카드는 2026-08-18에 제거 — 우상단 `QuickActionsBox`(map_screen.dart)로
/// 진입점이 이미 있어 중복이었고, 도감 요약을 보여주려고 매번 `/api/monsters/config`를 호출하는
/// 게 이 화면(원래는 로컬 sqlite만 읽어도 되는 가벼운 화면)의 체감 로딩을 불필요하게 늦추고
/// 있었음(사용자 피드백) — 제거 후 이 화면은 다시 순수 로컬 읽기(관광지 재동기화 버튼 제외)로 남음.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.initialProfile,
    required this.profileFetchFailed,
  });

  /// `AccountButton`이 진입 직전에 이미 한 번 조회해둔 값 — 여기서 다시 조회하지 않고 그대로
  /// 시작 상태로 씀(로그인/온보딩 판단은 호출부가 이미 끝냈으므로 이 화면은 순수 표시+수정만 담당).
  final UserProfile? initialProfile;
  final bool profileFetchFailed;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _tourismSpotRepository = const TourismSpotRepository();

  UserProfile? _profile;
  late bool _profileFetchFailed;
  bool _busy = false;
  bool _tourismResyncing = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _profileFetchFailed = widget.profileFetchFailed;
  }

  /// 닉네임 온보딩(최초 설정)과 수정을 하나로 통일 — 둘 다 "텍스트 입력 → upsertProfile" 동작이
  /// 완전히 같아서, 기존 값이 있으면 채워진 채(수정) 없으면 빈 채(온보딩) 같은 다이얼로그로 처리.
  /// 다이얼로그 자체는 `nickname_dialog.dart`(컨트롤러 dispose 타이밍 버그 수정 내역 참고) 공용 위젯.
  Future<void> _editNickname(AuthSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final client = AuthorizedApiClient(session, locale: apiLocaleOf(context));
    final api = AuthApi(client);
    try {
      final nickname = await showNicknameDialog(
        context,
        initialNickname: _profile?.nickname ?? '',
      );
      if (nickname == null) return;
      if (nickname.isEmpty) {
        _showSnackBar(l10n.nicknameEmptyError);
        return;
      }
      setState(() => _busy = true);
      final profile = await api.upsertProfile(nickname);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileFetchFailed = false;
      });
    } catch (e) {
      _showSnackBar(l10n.nicknameSaveError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 마이페이지에서 로그아웃 후 다시 로그인하는 경로 — 성공하면 온보딩 여부에 따라 닉네임
  /// 다이얼로그를 이어서 띄우고(`_editNickname` 재사용), 게스트→회원 마이그레이션/복구도 트리거.
  Future<void> _login(AuthSession session) async {
    final l10n = AppLocalizations.of(
      context,
    )!; // 아래 await들 전에 미리 확보(비동기 갭 이후 context 사용 지양)
    setState(() => _busy = true);
    try {
      await session.login();
      if (!mounted) return;
      final client = AuthorizedApiClient(session, locale: apiLocaleOf(context));
      UserProfile? profile;
      var fetchFailed = false;
      try {
        profile = await AuthApi(client).fetchProfile();
      } catch (e) {
        // 여기서 예외가 나면(신규 유저의 정상 404는 fetchProfile()이 null로 흡수하므로 안 옴)
        // 닉네임 다이얼로그도 안 뜨고 "계정 정보를 불러오지 못했습니다"만 보이는데, 원인이 뭔지
        // (네트워크 타임아웃/서버 오류/인증 실패) 알 수 있게 로그로 남김(2026-08-26, 사용자 리포트
        // — 로그인 직후 이 화면에서 재현됨).
        developer.log('로그인 직후 fetchProfile 실패: $e', name: 'MyPageScreen');
        fetchFailed = true;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileFetchFailed = fetchFailed;
      });
      if (profile == null && !fetchFailed) {
        await _editNickname(session);
      } else if (profile != null) {
        await syncGuestDataWithServer(client);
      }
    } on AuthCancelledException {
      // 사용자가 로그인 브라우저를 스스로 닫은 경우 — 조용히 무시.
    } catch (e) {
      _showSnackBar(l10n.genericErrorMessage('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout(AuthSession session) async {
    final l10n = AppLocalizations.of(context)!; // await 전에 미리 확보 — 아래 참고
    await session.logout();
    _showSnackBar(l10n.loggedOutMessage);
  }

  /// AS(TheBlueButter)의 계정 관리 페이지("연동 서비스 관리" → "연결 해제")로 이동 — 로그인 자체는
  /// 즉시 차단되지만, TourMon 쪽 저장 데이터(닉네임)를 이 버튼이 직접 지우는 건 아님. 실제 파기는
  /// TourMon Next.js의 `membership-events` 폴링(Auth_Server_Folder Document/connect_manual.md §8-4,
  /// TourMon/src/lib/deletion-sync/)이 32일 유예 뒤 비동기로 처리함(Document/temp.md §6).
  Future<void> _openAccountManagement() async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse('${AuthConfig.requireIssuer}/account');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar(l10n.unlinkLaunchFailedMessage(''));
      }
    } catch (e) {
      _showSnackBar(l10n.unlinkLaunchFailedMessage('$e'));
    }
  }

  /// TourMon Next.js가 호스팅하는 `/terms`, `/privacy` 정적 페이지를 외부 브라우저로 연다 —
  /// 로그인 여부와 무관하게 항상 노출되는 링크라 게스트도 볼 수 있어야 함(Auth_Server의 동의
  /// 화면은 로그인 시점에만 뜨므로 그것과는 별개의 상시 진입점). `apiLocaleOf`/`withLocale`은
  /// `api_locale.dart`의 기존 헬퍼 재사용 — 앱이 표시 중인 언어를 그대로 쿼리파라미터로 넘기면
  /// 서버(`resolveLegalLocale`)가 같은 규칙으로 로케일을 고른다.
  Future<void> _openLegalPage(String path) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = withLocale(
      Uri.parse('${ApiConfig.requireBaseUrl}$path'),
      apiLocaleOf(context),
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showSnackBar(l10n.unlinkLaunchFailedMessage(''));
      }
    } catch (e) {
      _showSnackBar(l10n.unlinkLaunchFailedMessage('$e'));
    }
  }

  // 이 화면(마이페이지)은 Navigator.push로 쌓인 화면이라, 아래 메서드들이 전부 await 뒤에
  // 부르는 메시지들은 사용자가 결과를 기다리다 뒤로 가버리면(화면 dispose) 로컬
  // ScaffoldMessenger.of(context)로는 못 띄움 — root_messenger.dart의 앱 전역 메신저를 씀
  // (`_resyncTourismData`와 같은 이유). l10n은 위 각 메서드에서 await 전에 미리 확보해둔 값이라
  // context가 이미 무효해졌어도 안전하게 쓸 수 있음.
  void _showSnackBar(String message) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _changeLanguage() async {
    final controller = context.read<LocaleController>();
    // 다이얼로그가 "시스템 언어 사용" 선택도 null이 아닌 별도 옵션으로 반환해야, showDialog가
    // 배리어 탭으로 취소됐을 때 돌려주는 진짜 null(선택 안 함)과 구분할 수 있음.
    final option = await _showLanguageDialog(context, controller.locale);
    if (option == null) return;
    await controller.setLocale(option.toLocale());
  }

  // 백그라운드 재동기화(map_screen.dart _maybeBackgroundResync)는 실패해도 조용히 무시하고 다음
  // 앱 실행 때 재시도하는 방식이라, 그 사이엔 사용자가 직접 재시도할 방법이 없었음 — 여기서 수동
  // 트리거 제공. syncBulk()는 전체 교체 방식이라 몇 번을 다시 눌러도 안전(멱등).
  //
  // 새로 받은 데이터는 지도 화면에 자동 반영되지 않음(재동기화해도 이미 그려진 마커는 그대로,
  // 지도를 다시 팬/줌해야 새로고침됨) — 그래서 완료 메시지에 "앱을 껐다 켜달라"는 안내를 포함함.
  Future<void> _resyncTourismData() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _tourismResyncing = true);
    try {
      await _tourismSpotRepository.syncBulk();
      _showSnackBar(l10n.tourismResyncSuccessMessage);
    } catch (e) {
      _showSnackBar(l10n.genericErrorMessage('$e'));
    } finally {
      if (mounted) setState(() => _tourismResyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = context.watch<AuthSession>();
    // 마이페이지는 계정/약관/탈퇴를 다루는 화면이라 지도·알 보관함·도감의 그림책+연필 스케치
    // 테마(config/sketch/)를 폰트·카드 모양까지 통째로 적용하진 않음(폰트는 앱 기본, 카드는
    // 손그림 테두리 대신 Material outlined Card) — 진지한 느낌 유지(2026-08-26, 사용자 요청).
    // 배경/AppBar/글자·아이콘 색만 다른 화면과 톤을 맞추려고 SketchTheme.paper/ink를 가져다 씀 —
    // 앱 전역 테마(app_theme.dart)가 다크 톤(밝은 글자색 전제)이라 크림 배경 위에서 그대로 쓰면
    // 글자가 거의 안 보였음. Builder로 새 context를 얻어야 아래 unlink 섹션의 Theme.of(context)가
    // 이 로컬 오버라이드를 잡음(다른 로컬 테마 적용 화면과 같은 이유, 2026-08-26).
    //
    // textTheme.apply()만으로는 부족함 — ListTile(언어/도움말/재동기화/약관 카드가 전부 이걸 씀)의
    // title/subtitle/leading·trailing 아이콘 기본색은 textTheme이 아니라 ColorScheme.onSurface·
    // onSurfaceVariant를 직접 읽고, leading/trailing은 ListTile 내부에서 IconTheme도 자체
    // 재계산해서 덮어써버려 위의 iconTheme 오버라이드까지 무시함(2026-08-26 실기기에서 옅은 회색
    // 글자/아이콘으로 확인) — 그래서 onSurface/onSurfaceVariant까지 같이 ink로 바꿔야 함.
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          onSurface: SketchTheme.ink,
          onSurfaceVariant: SketchTheme.ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: SketchTheme.paper,
          foregroundColor: SketchTheme.ink,
          elevation: 0,
        ),
        iconTheme: const IconThemeData(color: SketchTheme.ink),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: SketchTheme.ink),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: SketchTheme.ink,
          iconColor: SketchTheme.ink,
        ),
        textTheme: Theme.of(context).textTheme
            .apply(bodyColor: SketchTheme.ink, displayColor: SketchTheme.ink),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: SketchTheme.ink),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(foregroundColor: SketchTheme.ink),
        ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: SketchTheme.paper,
          appBar: AppBar(title: Text(l10n.myPageTitle)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileSection(
                session: session,
                profile: _profile,
                fetchFailed: _profileFetchFailed,
                busy: _busy,
                onEditNickname: () => _editNickname(session),
                onLogin: () => _login(session),
                onLogout: () => _logout(session),
              ),
              const SizedBox(height: 24),
              _LanguageCard(
                label: _LanguageOption.fromLocale(
                  context.watch<LocaleController>().locale,
                ).label(l10n),
                onTap: _changeLanguage,
              ),
              const SizedBox(height: 12),
              _HowToPlayCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(replay: true),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _HelpCard(onTap: () => _openLegalPage('/help')),
              const SizedBox(height: 12),
              _ResyncCard(
                busy: _tourismResyncing,
                onTap: _tourismResyncing ? null : _resyncTourismData,
              ),
              const SizedBox(height: 12),
              _LegalLinksCard(
                onTapTerms: () => _openLegalPage('/terms'),
                onTapPrivacy: () => _openLegalPage('/privacy'),
                onTapCredits: () => _openLegalPage('/credits'),
              ),
              if (session.isLoggedIn) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.unlinkSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.unlinkExplanationMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _openAccountManagement,
                  child: Text(l10n.unlinkButtonLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.session,
    required this.profile,
    required this.fetchFailed,
    required this.busy,
    required this.onEditNickname,
    required this.onLogin,
    required this.onLogout,
  });

  final AuthSession session;
  final UserProfile? profile;
  final bool fetchFailed;
  final bool busy;
  final VoidCallback onEditNickname;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!session.isLoggedIn) {
      return Card.outlined(
        key: const ValueKey('profile-guest'),
        color: SketchTheme.paperLight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.guestBannerMessage)),
              TextButton(
                onPressed: busy ? null : onLogin,
                child: Text(l10n.loginLabel),
              ),
            ],
          ),
        ),
      );
    }
    return Card.outlined(
      key: const ValueKey('profile-logged-in'),
      color: SketchTheme.paperLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.person, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fetchFailed
                    ? l10n.accountFetchError
                    : (profile != null
                          ? l10n.loggedInAs(profile!.nickname)
                          : ''),
              ),
            ),
            if (!fetchFailed && profile != null)
              IconButton(
                key: const ValueKey('edit-nickname-button'),
                icon: const Icon(Icons.edit),
                tooltip: l10n.editNicknameTooltip,
                onPressed: busy ? null : onEditNickname,
              ),
            TextButton(
              key: const ValueKey('logout-button'),
              onPressed: busy ? null : onLogout,
              child: Text(l10n.logoutButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      color: SketchTheme.paperLight,
      child: ListTile(
        leading: const Icon(Icons.language, size: 32),
        title: Text(
          l10n.languageSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// TourMon Next.js가 호스팅하는 `/help` 문제 해결 페이지 진입점 — 삼성 헬스/Health Connect
/// 설정처럼 OS·제조사 UI 버전마다 문구가 바뀌는 안내는 앱 안에 박아두면 스토어 재배포 없이는
/// 못 고치므로, 약관/개인정보처리방침과 같은 방식(서버 정적 페이지 + 외부 브라우저)으로 둠.
class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      color: SketchTheme.paperLight,
      child: ListTile(
        leading: const Icon(Icons.help_outline, size: 32),
        title: Text(
          l10n.appNotWorkingLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}

/// 앱 최초 실행 때 뜨는 핵심 루프 안내 캐러셀을 다시 여는 진입점 — 한 번 스킵하면 다시 볼 수
/// 없는 걸 방지(onboarding_screen.dart의 [OnboardingScreen.replay]).
class _HowToPlayCard extends StatelessWidget {
  const _HowToPlayCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      color: SketchTheme.paperLight,
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined, size: 32),
        title: Text(
          l10n.howToPlayTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ResyncCard extends StatelessWidget {
  const _ResyncCard({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      color: SketchTheme.paperLight,
      child: ListTile(
        leading: const Icon(Icons.sync, size: 32),
        title: Text(
          l10n.tourismResyncTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(l10n.tourismResyncSubtitle),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _LegalLinksCard extends StatelessWidget {
  const _LegalLinksCard({
    required this.onTapTerms,
    required this.onTapPrivacy,
    required this.onTapCredits,
  });

  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;
  final VoidCallback onTapCredits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card.outlined(
      color: SketchTheme.paperLight,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined, size: 32),
            title: Text(
              l10n.legalLinksSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(l10n.viewTermsOfServiceLabel),
            trailing: const Icon(Icons.open_in_new),
            onTap: onTapTerms,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const SizedBox(width: 32),
            title: Text(l10n.viewPrivacyPolicyLabel),
            trailing: const Icon(Icons.open_in_new),
            onTap: onTapPrivacy,
          ),
          const Divider(height: 1),
          // 관광 정보/사진(한국관광공사 TourAPI, 공공누리 제1유형)과 지도 데이터(OpenStreetMap)
          // 출처표시를 상시 볼 수 있는 고정 진입점 — 상세 시트의 인라인 캡션과 별개로,
          // 상세를 안 열어도 접근 가능해야 해서 여기에 둠. 문구는 서버 /credits 페이지에 있어
          // 스토어 재배포 없이 갱신 가능.
          ListTile(
            leading: const SizedBox(width: 32),
            title: Text(l10n.viewCreditsLabel),
            trailing: const Icon(Icons.open_in_new),
            onTap: onTapCredits,
          ),
        ],
      ),
    );
  }
}

/// `LocaleController.setLocale`이 받는 `Locale?`은 "시스템 언어 사용"도 null로 표현하는데,
/// 다이얼로그의 반환값을 그대로 null로 쓰면 "취소(배리어 탭)"와 구분이 안 됨 — 그래서 다이얼로그
/// 자체는 이 enum(항상 non-null 선택지)을 반환하고, 취소만 null로 남긴다.
// 'ko'/'en' 코드↔옵션 매핑은 이 enum 하나에만 있음 — 라벨(label)/현재값 판별(fromLocale) 전부
// 여기 위임해서, 호출부(build()/_showLanguageDialog)에는 언어 코드 문자열이 등장하지 않게 함.
enum _LanguageOption {
  system,
  korean,
  english;

  Locale? toLocale() {
    switch (this) {
      case _LanguageOption.system:
        return null;
      case _LanguageOption.korean:
        return const Locale('ko');
      case _LanguageOption.english:
        return const Locale('en');
    }
  }

  static _LanguageOption fromLocale(Locale? locale) {
    switch (locale?.languageCode) {
      case 'ko':
        return _LanguageOption.korean;
      case 'en':
        return _LanguageOption.english;
      default:
        return _LanguageOption.system;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case _LanguageOption.system:
        return l10n.languageSystemOption;
      case _LanguageOption.korean:
        return l10n.languageKoreanOption;
      case _LanguageOption.english:
        return l10n.languageEnglishOption;
    }
  }
}

Future<_LanguageOption?> _showLanguageDialog(
  BuildContext context,
  Locale? current,
) {
  final l10n = AppLocalizations.of(context)!;
  final currentOption = _LanguageOption.fromLocale(current);
  return showDialog<_LanguageOption>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.languageDialogTitle),
      children: [
        for (final option in _LanguageOption.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(option),
            child: Row(
              children: [
                Icon(
                  option == currentOption
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(option.label(l10n)),
              ],
            ),
          ),
      ],
    ),
  );
}
