import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'config/map_config.dart';
import 'features/auth/auth_session.dart';
import 'features/map/map_screen.dart';
import 'features/steps/step_tracker_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'root_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FMTCObjectBoxBackend().initialise();
  await FMTCStore(MapConfig.tileCacheStoreName).manage.create();

  final authSession = AuthSession();

  // 4단계 — 앱 실행 내내 걸음수를 수집해 파트너 알에 적립. 권한 거부 시 조용히 스킵(로그만 남김) —
  // 사용자가 나중에 시스템 설정에서 권한을 켜면 다음 실행부터 정상 동작.
  // 6단계 Phase 5 — authSession을 넘겨서 로그인 상태면 걸음수를 서버에도 주기적으로 동기화.
  unawaited(StepTrackerService.instance.start(authSession));

  // 6단계 Phase 2 — 저장된 refresh token이 있으면 조용히 재로그인. 실패해도(만료/폐기)
  // AuthSession이 자체적으로 게스트 상태로 되돌리므로 여기서 별도 에러 처리 불필요.
  unawaited(authSession.tryRestoreSession());

  // 마이페이지 "언어 선택" — 저장된 값이 있으면 그 값, 없으면 null(기기 OS locale)로
  // MaterialApp.locale을 채움. TourMonApp을 감싸서 _TourMonAppState.build()의 context 기준으로
  // 조상이 되게 함(그 build() 안에서 곧바로 MaterialApp을 만들기 때문에, AuthSession 때처럼
  // build() 내부에 Provider를 두면 MaterialApp.locale 계산 시점엔 아직 조상이 아니라 못 읽음).
  final localeController = LocaleController();
  unawaited(localeController.load());

  runApp(
    ChangeNotifierProvider.value(
      value: localeController,
      child: TourMonApp(authSession: authSession),
    ),
  );
}

class TourMonApp extends StatefulWidget {
  const TourMonApp({super.key, required this.authSession});

  final AuthSession authSession;

  @override
  State<TourMonApp> createState() => _TourMonAppState();
}

/// 6단계 Phase 5 — 앱이 백그라운드로 전환되는 순간 걸음수를 즉시 1회 서버에 동기화하기 위해
/// WidgetsBindingObserver로 앱 생명주기를 관찰(init_plan.md 4-3: "백그라운드 전환 시 즉시 1회
/// 동기화"). 앱 전체에서 딱 한 번만 있으면 되는 관찰이라 루트 위젯에 둠.
class _TourMonAppState extends State<TourMonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    StepTrackerService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(StepTrackerService.instance.syncPendingStepsToServer());
    }
  }

  @override
  Widget build(BuildContext context) {
    // 마이페이지에서 저장한 값이 있으면 그 값, 없으면 null(기기 OS locale 따라감, 아래
    // 기본 해석 로직 그대로 적용) — locale_controller.dart 참고.
    final locale = context.watch<LocaleController>().locale;
    return ChangeNotifierProvider.value(
      value: widget.authSession,
      child: MaterialApp(
        title: 'TourMon',
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.themeData,
        // 7단계 — 기기 로케일 기반 자동 선택(저장된 값이 없을 때), 미지원 로케일은 ko로 폴백
        // (init_plan.md 4-7 섹션 확정 설계). Flutter 기본 로케일 해석(basicLocaleListResolution)은
        // 매칭 실패 시 supportedLocales의 "첫 번째" 항목으로 폴백하는데, gen-l10n이 자동 생성하는
        // AppLocalizations.supportedLocales는 알파벳순(en이 ko보다 먼저)이라 그대로 쓰면
        // 의도와 반대로 en 폴백이 돼버림 — 그래서 순서를 직접 ko 먼저로 지정.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('ko'), Locale('en')],
        locale: locale,
        home: const MapScreen(),
      ),
    );
  }
}
