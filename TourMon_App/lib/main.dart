import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';

import 'audio/sfx.dart';
import 'config/app_info.dart';
import 'config/app_theme.dart';
import 'config/game_config.dart';
import 'config/map_config.dart';
import 'features/auth/auth_session.dart';
import 'features/distance/distance_tracker_service.dart';
import 'features/map/map_screen.dart';
import 'features/remote_config/app_gate.dart';
import 'features/remote_config/remote_config_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'root_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FMTCObjectBoxBackend().initialise();
  await FMTCStore(MapConfig.tileCacheStoreName).manage.create();

  // 최소 지원 빌드 게이트가 비교할 설치 빌드 번호를 먼저 읽어둠(RemoteConfigService/AppGate 참고).
  await AppInfo.init();

  // 효과음 프리로드 + 오디오 세션 설정(Document/sound_effect_plan.md). 실패해도 무음으로 계속.
  unawaited(Sfx.instance.init());

  final authSession = AuthSession();

  // 거리 측정 이중화(Document/temp.md) — GPS 주 경로는 지도 화면 위치 스트림이 구동하고, 여기선
  // pedometer 보조 경로 구독 + 서버 flush 타이머를 시작. requestPermissionIfNeeded: false —
  // ACTIVITY_RECOGNITION 권한이 이미 있는 재방문 유저만 조용히 재개되고, 신규 유저는 지도도 보기
  // 전에 권한 팝업이 뜨지 않음(JIT). 실제 권한 요청은 파트너 알을 처음 지정하는 시점에
  // EggInventoryScreen이 트리거함. authSession을 넘겨서 로그인 상태면 델타를 서버에도 동기화.
  unawaited(
    DistanceTrackerService.instance.start(
      authSession,
      requestPermissionIfNeeded: false,
    ),
  );

  // 6단계 Phase 2 — 저장된 refresh token이 있으면 조용히 재로그인. 실패해도(만료/폐기)
  // AuthSession이 자체적으로 게스트 상태로 되돌리므로 여기서 별도 에러 처리 불필요.
  // 게스트 전용 출시(GameConfig.accountsEnabled=false, Document/temp.md)에서는 이 조용한 재로그인도
  // 건너뛴다 — 새 설치엔 저장된 토큰이 없어 어차피 no-op이지만, 출시 전 테스트로 로그인했던 기기가
  // 로그인 상태로 남아 게스트 전용 전제(서버에 사용자 위치정보 미기록)를 깨는 걸 막기 위함. 저장된
  // refresh token은 secure storage에 그대로 두고, 나중에 계정 재활성화 시 다시 복구됨.
  if (GameConfig.accountsEnabled) {
    unawaited(authSession.tryRestoreSession());
  }

  // 원격 공지 + 최소 지원 빌드 게이트 — 캐시된 값을 즉시 반영하고 CDN에서 갱신 시도(fire-and-forget).
  // 백엔드가 아니라 tourmon-asset-cdn 워커가 서빙하므로 서버가 죽어도 공지는 뜸(Document/worker_manual.md).
  unawaited(RemoteConfigService.instance.load());

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

/// 거리 측정 이중화(Document/temp.md) — 앱 생명주기 전환을 관찰해 pedometer 보조 경로의
/// baseline/diff를 처리한다. `paused`에서 그 순간의 누적 걸음수를 baseline으로 persist하고(+ GPS
/// 앵커 리셋 플래그를 세움, 5-c), `resumed`에서 그 사이 늘어난 걸음을 거리로 환산해 "앱이 꺼져있던
/// 동안의 이동"으로 적립한다. 양쪽 모두에서 미전송 델타를 서버로 flush도 시도(실패해도 무해).
/// 앱 전체에서 딱 한 번만 있으면 되는 관찰이라 루트 위젯에 둔다.
class _TourMonAppState extends State<TourMonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DistanceTrackerService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tracker = DistanceTrackerService.instance;
    if (state == AppLifecycleState.paused) {
      unawaited(tracker.onAppPaused());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(tracker.onAppResumed());
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
        debugShowCheckedModeBanner: false,
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
        home: const AppGate(child: MapScreen()),
      ),
    );
  }
}
