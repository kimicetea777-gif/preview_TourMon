import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:provider/provider.dart';

import 'config/app_info.dart';
import 'config/app_theme.dart';
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

  final authSession = AuthSession();

  // 4단계 — 앱 실행 내내 Health Connect 거리를 수집해 파트너 알에 적립(Health Connect 전환,
  // Document/temp.md "통합 결정"). requestPermissionIfNeeded: false — 권한이 이미 있는 재방문
  // 유저만 조용히 재개되고, 아직 한 번도 파트너 알을 설정 안 한(=권한 요청 전) 신규 유저는 지도도
  // 보기 전에 건강 데이터 동의 다이얼로그가 뜨지 않음(temp.md 미결 사항 "just-in-time" 결정) —
  // 실제 권한 요청은 파트너 알을 처음 지정하는 시점에 EggInventoryScreen이 트리거함.
  // 6단계 Phase 5 — authSession을 넘겨서 로그인 상태면 거리를 서버에도 주기적으로 동기화.
  unawaited(
    DistanceTrackerService.instance.start(
      authSession,
      requestPermissionIfNeeded: false,
    ),
  );

  // 6단계 Phase 2 — 저장된 refresh token이 있으면 조용히 재로그인. 실패해도(만료/폐기)
  // AuthSession이 자체적으로 게스트 상태로 되돌리므로 여기서 별도 에러 처리 불필요.
  unawaited(authSession.tryRestoreSession());

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

/// 6단계 Phase 5 — 앱이 백그라운드로 전환되는 순간 거리를 즉시 1회 서버에 동기화하기 위해
/// WidgetsBindingObserver로 앱 생명주기를 관찰(init_plan.md 4-3: "백그라운드 전환 시 즉시 1회
/// 동기화"). 앱 전체에서 딱 한 번만 있으면 되는 관찰이라 루트 위젯에 둠.
///
/// `resumed`(포그라운드 복귀)에도 동기화(실기기 확인, 2026-08-27). Health Connect는 STEPS를 앱이
/// 포그라운드일 때만 읽게 하고, 백그라운드 읽기 권한(`READ_HEALTH_DATA_IN_BACKGROUND`)은 심사
/// 리스크 때문에 요청하지 않기로 정했다(2026-08-29, `Document/study_folder/4-1_Health Connect
/// 전환.md`). 그래서 `paused` 동기화는 어느 기기에서든 STEPS 읽기가 RemoteException으로 실패할 수
/// 있는 best-effort고(syncNow의 catch가 삼킴), 실제 따라잡기는 `resumed` 때 이뤄진다 — syncNow가
/// [마지막 반영 시각, now) 하루 전체를 재조회하므로 그사이 쌓인 걸음수를 유실 없이 반영한다
/// (self-healing). `paused`를 그대로 두는 이유는 로그인 유저의 미전송 델타(pending_server_sync)를
/// 백그라운드 직전에 한 번 더 flush하려는 시도라도 남겨두는 편이 낫고, 실패해도 무해하기 때문.
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(DistanceTrackerService.instance.syncNow());
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
