import 'dart:async';
import 'dart:developer' as developer;

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/game_config.dart';
import '../../data/app_settings_repository.dart';
import '../../data/daily_steps_repository.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../egg/egg_repository.dart';
import 'step_sync_api.dart';

/// 4단계 — 걸음수 측정 → 파트너 알 누적. `pedometer` 패키지는 Android에서 TYPE_STEP_COUNTER
/// (기기 마지막 부팅 이후 누적치)를 그대로 스트리밍함 — 앱이 완전히 꺼져 있던 동안의 걸음수도
/// 다음 실행 시 첫 이벤트에 반영되므로, 별도 백그라운드 서비스 없이도 "앱을 껐다 켜면 그동안
/// 걸은 걸음이 반영"되는 동작을 얻을 수 있음(포켓몬고 등 업계 표준 만보기 앱과 동일한 원리).
/// 마지막으로 처리한 누적치(_lastRawStepCountKey)를 로컬에 저장해두고, 새 이벤트가 올 때마다
/// 그 차이(delta)만 파트너 알에 적립. 델타 계산이 세션(구독) 시작 시점이 아니라 영구 저장된
/// 기준선 기준이라는 게 핵심 — iOS(CMPedometer)는 기준 시점 이후 누적치를 보고하는 방식이 달라서
/// 실기기 검증 시 동작을 다시 확인할 것(지금은 Android 개발/검증만 진행 중).
///
/// 6단계 Phase 5 — 로그인 상태면 로컬 누적과 별개로 서버에도 델타를 동기화(init_plan.md 4-3
/// "걸음수 서버 동기화"). 로컬 sqlite는 그대로 진행도 표시의 기준으로 남고(변경 없음), 서버는
/// 주기적으로 델타만 받아 자기 사본에 누적 — 목표 걸음수 달성 판정(부화 승인)의 근거가 됨.
class StepTrackerService {
  StepTrackerService._();
  static final StepTrackerService instance = StepTrackerService._();

  static const _lastRawStepCountKey = 'pedometer_last_raw_step_count';
  // 서버로 아직 못 보낸 델타 누적치 — 로컬 걸음수 적립과는 별개 카운터. 동기화 성공 시에만 0으로
  // 리셋하고, 실패하면 그대로 둬서 다음 시도 때 따라잡힘(init_plan.md: "동기화 실패해도 다음
  // 시도 때 따라잡히므로 데이터 유실 없음"). 마이그레이션(Phase 4) 직후에도 0으로 리셋됨 —
  // migrate가 이미 로컬의 현재 누적치를 절대값으로 서버에 실어보내므로, 그 이전 델타를 또 더하면
  // 이중 계산됨(migration_service.dart 참고).
  static const _pendingServerSyncDeltaKey = 'pending_server_sync_delta';

  final _settings = const AppSettingsRepository();
  final _eggRepository = const EggRepository();
  final _dailyStepsRepository = const DailyStepsRepository();

  AuthSession? _authSession;
  StreamSubscription<StepCount>? _subscription;
  Timer? _syncTimer;
  bool _starting = false;

  // daily_steps 전용 세션 기준선(메모리 전용, 저장 안 함) — 파트너 알 적립용 영구 기준선
  // (_lastRawStepCountKey)과 완전히 분리(Document/plan/later.md "해결" 절 설계). 앱 프로세스가
  // 켜져서 이 스트림의 첫 이벤트를 받는 순간 그 값을 기준으로 세우고, 이후 델타만 오늘 날짜
  // daily_steps row에 적립 — 앱이 완전히 꺼져있던 동안의 걸음은 반영 안 됨(가짜 스파이크 대신
  // 과소집계, 의도된 트레이드오프). 파트너 알 진행/부화는 기존 기준선 로직 그대로라 영향 없음.
  int? _dailySessionBaseline;

  Future<void> start(AuthSession authSession) async {
    _authSession = authSession;
    _syncTimer ??= Timer.periodic(
      GameConfig.stepServerSyncInterval,
      (_) => syncPendingStepsToServer(),
    );
    if (_subscription != null || _starting) return;
    _starting = true;
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        developer.log('걸음수 권한 거부됨 — 파트너 알 진행 불가', name: 'StepTrackerService');
        return;
      }
      _subscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (Object error) {
          developer.log('걸음수 스트림 오류: $error', name: 'StepTrackerService');
        },
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> _onStepCount(StepCount event) async {
    final rawSteps = event.steps;
    await _accumulateDailySessionSteps(rawSteps);

    final storedBaseline = await _settings.getValue(_lastRawStepCountKey);

    if (storedBaseline == null) {
      // 최초 실행 — 기기가 그동안 쌓아온 걸음수 전체를 한 번에 적립하면 안 되므로 기준선만 세움.
      await _settings.setValue(_lastRawStepCountKey, '$rawSteps');
      return;
    }

    final baseline = int.tryParse(storedBaseline) ?? rawSteps;
    if (rawSteps < baseline) {
      // 기기 재부팅 등으로 TYPE_STEP_COUNTER가 리셋된 경우 — 새 기준선만 세우고 이번 델타는 버림.
      await _settings.setValue(_lastRawStepCountKey, '$rawSteps');
      return;
    }

    final delta = rawSteps - baseline;
    if (delta > 0) {
      await _eggRepository.addStepsToPartners(delta);
      await _addPendingServerSyncDelta(delta);
    }
    await _settings.setValue(_lastRawStepCountKey, '$rawSteps');
  }

  /// 오늘 날짜 daily_steps row에 델타 적립 — 파트너 알 적립(_onStepCount 나머지 로직)과 완전히
  /// 독립된 세션 기준선을 씀(클래스 상단 주석 참고).
  Future<void> _accumulateDailySessionSteps(int rawSteps) async {
    final baseline = _dailySessionBaseline;
    if (baseline == null || rawSteps < baseline) {
      // 최초 이벤트, 또는 기기 재부팅으로 카운터가 리셋된 경우 — 새 세션 기준선만 세움.
      _dailySessionBaseline = rawSteps;
      return;
    }
    final delta = rawSteps - baseline;
    _dailySessionBaseline = rawSteps;
    if (delta > 0) {
      await _dailyStepsRepository.addStepsToday(delta);
    }
  }

  Future<void> _addPendingServerSyncDelta(int delta) async {
    final stored = await _settings.getValue(_pendingServerSyncDeltaKey);
    final current = int.tryParse(stored ?? '0') ?? 0;
    await _settings.setValue(_pendingServerSyncDeltaKey, '${current + delta}');
  }

  /// 마이그레이션(Phase 4)이 로컬의 현재 누적치를 서버에 절대값으로 실어보낸 직후 호출됨 —
  /// 그 시점 이전에 쌓인 pending 델타를 또 더하면 이중 계산되므로 0으로 리셋.
  Future<void> resetPendingServerSyncDelta() async {
    await _settings.setValue(_pendingServerSyncDeltaKey, '0');
  }

  /// 포그라운드 타이머 + 백그라운드 전환 시 둘 다 이걸 호출. 게스트면 조용히 무시(서버에 상태
  /// 자체가 없으므로). 실패해도 예외를 삼킴 — 다음 시도 때 pending이 그대로 남아 따라잡힘.
  Future<void> syncPendingStepsToServer() async {
    final session = _authSession;
    if (session == null || !session.isLoggedIn) return;

    final stored = await _settings.getValue(_pendingServerSyncDeltaKey);
    final pending = int.tryParse(stored ?? '0') ?? 0;
    if (pending <= 0) return;

    try {
      final api = StepSyncApi(AuthorizedApiClient(session));
      await api.sync(pending);
      await _settings.setValue(_pendingServerSyncDeltaKey, '0');
    } catch (e) {
      developer.log('걸음수 서버 동기화 실패(다음 시도 때 재시도): $e', name: 'StepTrackerService');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
