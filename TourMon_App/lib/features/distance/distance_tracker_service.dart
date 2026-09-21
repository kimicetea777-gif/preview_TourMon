import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/game_config.dart';
import '../../data/app_settings_repository.dart';
import '../../data/daily_distance_repository.dart';
import '../../data/day_key.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../egg/egg_repository.dart';
import 'distance_sync_api.dart';

/// 거리 측정 이중화(Document/temp.md "거리 측정 이중화 — GPS 포그라운드 추적을 주 경로로,
/// pedometer를 보조 경로로") — 삼성 헬스↔Health Connect 동기화가 자주 끊기는 문제를 계기로
/// Health Connect/삼성 헬스를 아예 걷어내고 두 경로로 거리를 적립한다.
///
/// **주 경로 = GPS 포그라운드 거리 측정.** 앱이 포그라운드인 동안(다른 화면에 있어도 프로세스가
/// 살아있으면 포함 — 실측 확인, temp.md 1번) `map_screen`이 소유한 연속 GPS 위치 스트림이 좌표
/// 간 이동 거리(haversine)를 계산해 [addGpsDelta]로 이 서비스에 넘긴다. 노이즈 필터(정지 drift,
/// 정확도, 순간이동 클램프)와 mock-location 감지는 `map_screen._onPositionFix`에서 처리하고,
/// 이 서비스는 게임 로직(일별 히스토리/파트너 알/서버 동기화)만 담당한다.
///
/// **보조 경로 = pedometer(`TYPE_STEP_COUNTER`).** 앱이 백그라운드로 전환되는 시점([onAppPaused])
/// 에 그 순간의 누적 걸음수를 baseline으로 persist하고, 포그라운드로 복귀하면([onAppResumed])
/// 그 사이 늘어난 걸음(diff)을 거리로 환산해 "앱이 꺼져있던 동안의 이동"으로 적립한다. GPS는
/// 이 구간 동안 애초에 안 돌고 있었으므로(temp.md 1번에서 확인한 경계와 정확히 일치) 겹칠 여지가
/// 구조적으로 없다.
///
/// - `TYPE_STEP_COUNTER`는 동기식 getter가 없어(`pedometer` 패키지도 `Stream<StepCount>`),
///   포그라운드인 동안 상시 구독해 최신값을 [_lastKnownStepCount]에 캐싱해두고, `paused`에선
///   새로 묻지 않고 캐싱된 값을 그대로 persist만 한다(temp.md 2번).
/// - baseline은 Dart 메모리가 아니라 [AppSettingsRepository]에 즉시 persist — 안드로이드가
///   백그라운드 프로세스를 메모리 회수로 죽이면 다음 실행이 cold start가 되므로, [start]에서도
///   저장된 baseline이 있으면 첫 스텝 이벤트 때 diff를 반영한다(self-healing).
/// - 재부팅으로 카운터가 0으로 리셋되면(현재값 < baseline) 그 구간은 diff 계산 불가라 적립을
///   스킵한다(temp.md 3번).
/// - `paused`↔`resumed` 구간은 GPS/mock 감지가 전혀 안 도는 사각지대라, 거리가 아니라 카덴스
///   (분당 걸음 수, [GameConfig.maxPlausibleStepsPerMinute]) 기준으로 diff 자체를 클램프하고,
///   시계 역전/경과시간 절대 상한 가드도 둔다(temp.md 4번).
///
/// 로그인 상태면 로컬 누적과 별개로 서버에도 델타를 주기적으로 동기화(init_plan.md 4-3). 로컬
/// sqlite는 그대로 진행도 표시의 기준으로 남고, 서버는 델타만 받아 자기 사본에 누적 — 목표 거리
/// 달성 판정(부화 승인)의 근거가 된다.
class DistanceTrackerService {
  DistanceTrackerService._();
  static final DistanceTrackerService instance = DistanceTrackerService._();

  // UI가 "N분 전 갱신" 상대 시각을 보여주는 기준 — 거리 수치가 실시간이 아니라(서버 flush는
  // 주기적) 일정 주기로만 서버에 반영된다는 걸 알리는 용도. 아직 한 번도 없으면 null.
  static const _lastSyncedAtKey = 'distance_last_synced_at';
  // 서버로 아직 못 보낸 델타 누적치(meters) — flush 성공 시에만 0으로 리셋하고, 실패하면 그대로
  // 둬서 다음 시도 때 따라잡힘. mock-location 플래그도 같이 들고 있다가 다음 서버 호출 때 함께
  // 실어보냄 — 거리가 0인 구간에서 mock만 감지된 경우도 서버 감사 로그에 남길 수 있게.
  static const _pendingServerSyncDeltaKey = 'pending_server_sync_delta_meters';
  static const _pendingMockDetectedKey = 'pending_server_sync_mock_detected';
  // 보조 경로(pedometer) — `paused` 시점의 누적 걸음수와 그 시각(ISO8601). `resumed`/cold start
  // 때 새 누적치와의 diff를 계산하고 나면 지운다.
  static const _pedometerBaselineKey = 'pedometer_background_baseline';
  static const _pedometerBaselineAtKey = 'pedometer_background_baseline_at';
  // 사용자가 알 보관함의 "앱이 꺼져 있어도 거리 측정" 토글을 켰는지(기본 false, opt-in). ON일 때만
  // pedometer 보조 경로를 구독한다. OFF는 앱 레벨 스위치일 뿐 — 안드로이드는 앱이 자기 런타임
  // 권한을 회수할 수 없으므로 OS 권한은 그대로 남지만 앱이 더는 걸음 스트림을 읽지 않는다.
  static const _bgDistanceEnabledKey = 'bg_distance_enabled';

  final _settings = const AppSettingsRepository();
  final _eggRepository = const EggRepository();
  final _dailyDistanceRepository = const DailyDistanceRepository();

  AuthSession? _authSession;
  Timer? _serverFlushTimer;
  bool _starting = false;
  bool _flushing = false;
  bool _serverBusy = false;

  // 보조 경로 상태.
  StreamSubscription<StepCount>? _pedometerSub;
  int? _lastKnownStepCount;
  bool _pendingResumedDiffCheck = false;

  // 정수 미터 단위로만 적립하는 파트너/서버 경로에서 소수부가 매번 버려지지 않도록 들고 있는
  // 잔여 누적치(메모리). cold start 시 유실되지만 최대 1m 미만이라 감수(daily_distance엔 소수
  // 그대로 적립됨).
  double _unappliedMeters = 0;

  // 5-c(temp.md) — `paused`가 한 번이라도 발생한 뒤의 첫 GPS 픽스는 거리 적립을 스킵하고 앵커만
  // 리셋해야 함(그 구간은 pedometer 전담, 이중 집계 방지). map_screen이 매 픽스에서 이 플래그를
  // 확인하고, 신선한 픽스로 앵커를 리셋한 뒤 [clearGpsAnchorPendingReset]로 내린다.
  bool _gpsAnchorPendingReset = false;
  // Stale Fix 방어(temp.md 5-c) — `resumed` 직후 OS가 내보내는 낡은 캐시 좌표를 앵커로 삼지
  // 않도록, map_screen이 `Position.timestamp`를 이 시각과 비교해 이전 픽스는 버린다.
  DateTime? _lastResumedAt;

  // `onAppPaused`가 첫 스텝 이벤트를 기다리는 폴링 도중(최대 3초) 사용자가 바로 앱으로 복귀하면
  // `onAppResumed`가 먼저 실행돼 "저장된 baseline 없음"으로 지나가는데, 뒤늦게 폴링이 끝나 그
  // 시점 기준 baseline을 저장해버리면 아무도 소비하지 않는 유령 baseline이 남는다 — 다음 진짜
  // pause~resume 때 그 유령 baseline부터 diff를 계산해서, 그사이 포그라운드로 있었던(이미 GPS로
  // 적립된) 구간까지 걸음으로 중복 적립될 수 있다. `onAppResumed`가 세대를 올리면 진행 중이던
  // 폴링이 이를 감지하고 저장을 포기하도록 막는다.
  int _pauseGeneration = 0;

  bool get _pedometerSupported => Platform.isAndroid;

  /// 서버 flush 타이머를 켜고(게스트도 로컬 적립엔 무관하지만 타이머 자체는 무해), pedometer
  /// 보조 경로를 시작한다. [requestPermissionIfNeeded]가 false면 `ACTIVITY_RECOGNITION` 권한이
  /// 이미 있을 때만 조용히 구독하고, 없으면 OS 권한 다이얼로그를 띄우지 않고 대기(앱 실행 직후
  /// main.dart는 항상 false — 지도도 보기 전에 권한 팝업이 뜨지 않도록, JIT 원칙).
  ///
  /// 반환값: pedometer 보조 경로가 활성(권한 확보 또는 비안드로이드)이면 true, 권한 거부로 못
  /// 켰으면 false. **주 경로(GPS)는 이 반환값과 무관하게 항상 동작하므로**, 호출부는 이 값으로
  /// 파트너 지정을 되돌리는 등의 하드 실패 처리를 하면 안 된다(temp.md 6번 graceful degradation).
  Future<bool> start(
    AuthSession authSession, {
    bool requestPermissionIfNeeded = true,
  }) async {
    _authSession = authSession;
    _serverFlushTimer ??= Timer.periodic(
      GameConfig.distanceServerSyncInterval,
      (_) => syncNow(),
    );

    if (!_pedometerSupported) return true;
    if (_pedometerSub != null) return true;
    if (_starting) return true;
    // 보조 경로는 사용자가 "앱이 꺼져 있어도 거리 측정"을 명시적으로 켠 경우에만 구독한다.
    // main.dart의 조용한 재개(requestPermissionIfNeeded: false)도 이 플래그가 살아있을 때만
    // pedometer를 다시 붙인다 — 안 켰으면 GPS 주 경로만 동작.
    if (!await isBackgroundDistanceEnabled()) return false;
    _starting = true;
    try {
      final granted = await _ensureActivityPermission(
        requestIfNeeded: requestPermissionIfNeeded,
      );
      if (!granted) {
        if (requestPermissionIfNeeded) {
          developer.log(
            'ACTIVITY_RECOGNITION 권한 없음 — 백그라운드 걸음 보조 경로 비활성(GPS 주 경로는 정상)',
            name: 'DistanceTrackerService',
          );
        }
        return false;
      }
      _subscribePedometer();
      // cold start(백그라운드에서 프로세스가 회수됨) — 저장된 baseline이 있으면 첫 스텝 이벤트
      // 때 diff를 반영(temp.md 2번 self-healing).
      if (await _hasStoredPedometerBaseline()) {
        _lastResumedAt ??= DateTime.now();
        _pendingResumedDiffCheck = true;
      }
      return true;
    } finally {
      _starting = false;
    }
  }

  /// 부작용 없이(권한 팝업 유도 안 함) 현재 `ACTIVITY_RECOGNITION` 권한이 있는지만 확인 —
  /// 파트너 박스의 복구 배너 노출 판단 등에 쓴다.
  Future<bool> hasActivityPermission() =>
      _ensureActivityPermission(requestIfNeeded: false);

  /// 사용자가 "앱이 꺼져 있어도 거리 측정" 토글을 켰는지(기본 false).
  Future<bool> isBackgroundDistanceEnabled() async =>
      (await _settings.getValue(_bgDistanceEnabledKey)) == 'true';

  /// 토글 ON — OS 신체활동 권한을 요청하고, 허용되면 플래그를 저장하고 pedometer 보조 경로를
  /// 켠다. 반환: 실제로 켜졌는지(권한 거부면 false, 플래그도 안 바뀜). 영구 거부 상태는 호출부가
  /// [isActivityPermissionPermanentlyDenied]로 먼저 걸러 설정 앱으로 보내야 한다.
  Future<bool> enableBackgroundDistance(AuthSession authSession) async {
    _authSession = authSession;
    if (!_pedometerSupported) return false;
    final granted = await _ensureActivityPermission(requestIfNeeded: true);
    if (!granted) return false;
    await _settings.setValue(_bgDistanceEnabledKey, 'true');
    _subscribePedometer();
    if (await _hasStoredPedometerBaseline()) {
      _lastResumedAt ??= DateTime.now();
      _pendingResumedDiffCheck = true;
    }
    return true;
  }

  /// 토글 OFF — 플래그를 내리고 pedometer 보조 경로를 멈춘다. OS 권한은 앱이 회수할 수 없어
  /// 그대로 두되(무해) 앱이 더는 걸음 스트림을 구독하지 않는다. 완전 해제는 시스템 설정에서.
  Future<void> disableBackgroundDistance() async {
    await _settings.setValue(_bgDistanceEnabledKey, 'false');
    _pedometerSub?.cancel();
    _pedometerSub = null;
    await _clearPedometerBaseline();
  }

  /// 영구 거부 상태 — 재요청해도 OS 팝업이 안 뜨므로 복구 경로는 설정 앱 열기로 분기해야 함
  /// (Document/temp.md 6-b).
  Future<bool> isActivityPermissionPermanentlyDenied() async {
    if (!_pedometerSupported) return false;
    return Permission.activityRecognition.isPermanentlyDenied;
  }

  /// 설정 앱 열기(영구 거부 복구 경로).
  Future<bool> openPermissionSettings() => openAppSettings();

  /// UI "N분 전 갱신" 표시용 — 마지막으로 서버 flush를 시도했거나 거리가 갱신된 시각.
  Future<DateTime?> lastSyncedAt() async {
    final raw = await _settings.getValue(_lastSyncedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> _ensureActivityPermission({required bool requestIfNeeded}) async {
    if (!_pedometerSupported) return false;
    var status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;
    if (!requestIfNeeded) return false;
    try {
      status = await Permission.activityRecognition.request();
    } catch (e) {
      developer.log(
        'ACTIVITY_RECOGNITION 권한 요청 실패: $e',
        name: 'DistanceTrackerService',
      );
      return false;
    }
    return status.isGranted;
  }

  void _subscribePedometer() {
    _pedometerSub ??= Pedometer.stepCountStream.listen(
      (event) {
        _lastKnownStepCount = event.steps;
        if (!_pendingResumedDiffCheck) return;
        // Stale/버퍼된 이벤트 방어 — resumed 이전 타임스탬프 이벤트로는 diff를 트리거하지 않음
        // (그 값은 pause 이전 캐시라 diff가 0/음수로 나와 진짜 백그라운드 걸음을 잃게 됨).
        final resumedAt = _lastResumedAt;
        if (resumedAt != null && event.timeStamp.isBefore(resumedAt)) return;
        _pendingResumedDiffCheck = false;
        unawaited(_applyPedometerBackgroundDiff(event.steps));
      },
      onError: (Object e) {
        developer.log(
          'pedometer 스트림 오류(보조 경로 일시 비활성): $e',
          name: 'DistanceTrackerService',
        );
      },
      cancelOnError: false,
    );
  }

  Future<bool> _hasStoredPedometerBaseline() async {
    final raw = await _settings.getValue(_pedometerBaselineKey);
    return raw != null && raw.isNotEmpty;
  }

  Future<void> _clearPedometerBaseline() async {
    await _settings.deleteValue(_pedometerBaselineKey);
    await _settings.deleteValue(_pedometerBaselineAtKey);
  }

  /// 앱이 백그라운드로 전환되는 시점(main.dart `didChangeAppLifecycleState`) — 보조 경로 baseline을
  /// persist하고, GPS 앵커 리셋 플래그를 세우고(5-c), 미전송 델타를 한 번 더 flush 시도.
  Future<void> onAppPaused() async {
    _gpsAnchorPendingReset = true;
    final generation = ++_pauseGeneration;
    // 보조 경로가 실제로 구독 중일 때만 baseline을 건드린다 — 권한이 없거나(구독 안 됨) 조용히
    // 스킵(temp.md 6번 graceful degradation).
    if (_pedometerSupported && _pedometerSub != null) {
      var steps = _lastKnownStepCount;
      // 이번 구독에서 스텝 이벤트를 한 번도 못 받은 경우(백그라운드 측정 토글을 막 켰거나, 직전
      // diff 반영으로 baseline이 막 클리어된 직후) — 첫 이벤트가 등록 직후 곧 도착하는 걸 감안해
      // 짧게 폴링 대기(GameConfig.pedometerPauseStepWaitInterval/Attempts). 그 사이 사용자가 바로
      // 복귀하면(onAppResumed가 세대를 올림) 이 폴링은 스스로 멈춘다 — 계속 진행해서 뒤늦게 저장해
      // 봤자 아무도 소비하지 않는 유령 baseline만 남고, 다음 진짜 pause~resume 때 그동안(대부분
      // 포그라운드였던, 이미 GPS로 적립된) 구간까지 걸음으로 중복 적립되는 문제로 이어진다.
      for (
        var i = 0;
        steps == null &&
            i < GameConfig.pedometerPauseStepWaitAttempts &&
            _pauseGeneration == generation;
        i++
      ) {
        await Future.delayed(GameConfig.pedometerPauseStepWaitInterval);
        steps = _lastKnownStepCount;
      }
      if (steps != null && _pauseGeneration == generation) {
        await _settings.setValue(_pedometerBaselineKey, '$steps');
        await _settings.setValue(
          _pedometerBaselineAtKey,
          DateTime.now().toIso8601String(),
        );
      }
    }
    await _flushPendingToServer();
  }

  /// 앱이 포그라운드로 복귀하는 시점 — 첫 신선한 스텝 이벤트가 오면 보조 경로 diff를 반영하도록
  /// 무장하고, 서버로 flush. 세대를 올려 진행 중일 수 있는 `onAppPaused`의 폴링을 무효화한다.
  Future<void> onAppResumed() async {
    _pauseGeneration++;
    _lastResumedAt = DateTime.now();
    if (_pedometerSupported && await _hasStoredPedometerBaseline()) {
      // 동기 getter가 없으므로 즉시 계산하지 않는다 — 캐시된 [_lastKnownStepCount]는 pause 이전
      // 값이라 diff가 0/음수로 나옴. 스트림의 다음 신선한 이벤트가 오면 그때 계산.
      _pendingResumedDiffCheck = true;
    }
    await _flushPendingToServer();
  }

  Future<void> _applyPedometerBackgroundDiff(int current) async {
    try {
      final baselineRaw = await _settings.getValue(_pedometerBaselineKey);
      final baselineAtRaw = await _settings.getValue(_pedometerBaselineAtKey);
      if (baselineRaw == null || baselineRaw.isEmpty) return;
      final baseline = int.tryParse(baselineRaw);
      final baselineAt = (baselineAtRaw == null || baselineAtRaw.isEmpty)
          ? null
          : DateTime.tryParse(baselineAtRaw);
      // 이 diff는 어떤 경로로 들어와도 한 번만 반영 — 먼저 baseline을 지운다.
      await _clearPedometerBaseline();
      if (baseline == null) return;

      // 3번 — 재부팅으로 카운터가 리셋됨(현재값 < baseline). diff 계산 불가, 그 구간 걸음은 유실 감수.
      if (current < baseline) {
        developer.log(
          'pedometer 카운터 리셋 감지(재부팅) — 이 구간 적립 스킵',
          name: 'DistanceTrackerService',
        );
        return;
      }
      final rawDiff = current - baseline;
      if (rawDiff <= 0) return;

      final now = DateTime.now();
      // 4번 — 시계 역전(baseline 시각이 지금보다 미래) 방어: diff 자체를 버림.
      if (baselineAt == null || now.isBefore(baselineAt)) {
        developer.log(
          'pedometer baseline 시각 이상(시계 역전?) — 적립 스킵',
          name: 'DistanceTrackerService',
        );
        return;
      }
      var elapsedMinutes = now.difference(baselineAt).inMinutes;
      // 절대 상한 — 극단적 시계 조작/장기 방치의 피해 규모 제한(4번).
      final capMinutes = GameConfig.backgroundBonusElapsedCapHours * 60;
      if (elapsedMinutes > capMinutes) elapsedMinutes = capMinutes;
      if (elapsedMinutes < 1) elapsedMinutes = 1;

      // 4번 — 카덴스(분당 걸음) 상한으로 diff 클램프. 정상 사용자는 안 걸리고 장시간 방치형
      // 흔들개만 상한에 막힘.
      final maxPlausibleSteps =
          elapsedMinutes * GameConfig.maxPlausibleStepsPerMinute;
      final appliedSteps = rawDiff < maxPlausibleSteps
          ? rawDiff
          : maxPlausibleSteps;
      if (appliedSteps <= 0) return;

      // 3-b — diff 전액을 `resumed` 시점 기준 "오늘"로 적립(리셋 경계를 걸친 구간의 정밀
      // 재분배는 하지 않음 — 보조 경로는 근사치 허용 영역이고, 위 카덴스 클램프가 왜곡의 최대
      // 규모도 함께 제한함). [_creditDistance]가 오늘 키로 적립.
      final meters = appliedSteps * GameConfig.stepsToMetersFactor;
      await _creditDistance(meters, mockDetected: false);
      await _flushPendingToServer();
    } catch (e) {
      developer.log(
        'pedometer 백그라운드 diff 반영 실패: $e',
        name: 'DistanceTrackerService',
      );
    }
  }

  /// GPS 주 경로 — `map_screen._onPositionFix`가 노이즈 필터/클램프를 거친 뒤 좌표 간 이동
  /// 거리(m)를 넘긴다. [mocked]는 그 픽스의 `Position.isMocked`(치팅 감사 로그용).
  Future<void> addGpsDelta(double meters, {required bool mocked}) async {
    try {
      await _creditDistance(meters, mockDetected: mocked);
    } catch (e) {
      developer.log('GPS 거리 적립 실패: $e', name: 'DistanceTrackerService');
    }
  }

  /// 디버그 전용 — 실제로 걷지 않고 거리 적립 전체 경로(일별 히스토리 → 파트너 알 → 서버 pending)
  /// 를 검증하기 위한 주입(debug_distance_injector_button.dart).
  Future<void> debugCreditMeters(double meters) async {
    await _creditDistance(meters, mockDetected: false);
    await _flushPendingToServer();
  }

  /// 두 경로 공용 적립 — 일별 히스토리(daily_distance)엔 소수 그대로, 파트너 알/서버 pending엔
  /// 정수 미터로 적립(소수부는 [_unappliedMeters]에 이월). 갱신 시각도 여기서 stamp.
  Future<void> _creditDistance(
    double meters, {
    required bool mockDetected,
  }) async {
    if (meters <= 0 && !mockDetected) return;
    final now = DateTime.now();
    if (meters > 0) {
      await _dailyDistanceRepository.addDistanceForDay(resetDayKey(now), meters);
      _unappliedMeters += meters;
    }
    final whole = _unappliedMeters.floor();
    if (whole > 0) {
      _unappliedMeters -= whole;
      await _eggRepository.addDistanceToPartners(whole);
      await _addPendingServerSync(whole, mockDetected);
    } else if (mockDetected) {
      await _addPendingServerSync(0, true);
    }
    await _settings.setValue(_lastSyncedAtKey, now.toIso8601String());
  }

  Future<void> _addPendingServerSync(int deltaMeters, bool mockDetected) async {
    final stored = await _settings.getValue(_pendingServerSyncDeltaKey);
    final current = int.tryParse(stored ?? '0') ?? 0;
    await _settings.setValue(
      _pendingServerSyncDeltaKey,
      '${current + deltaMeters}',
    );
    if (mockDetected) {
      await _settings.setValue(_pendingMockDetectedKey, 'true');
    }
  }

  /// 마이그레이션(Phase 4)이 로컬의 현재 누적치를 서버에 절대값으로 실어보낸 직후 호출됨 —
  /// 그 시점 이전에 쌓여있던 pending 델타를 또 더하면 이중 계산되므로 0으로 리셋.
  Future<void> resetPendingServerSyncDelta() async {
    await _settings.setValue(_pendingServerSyncDeltaKey, '0');
    await _settings.setValue(_pendingMockDetectedKey, 'false');
  }

  /// flush 성공 후 — **보낸 만큼만** 차감한다(0으로 blind reset하지 않음). GPS 델타는
  /// `_flushPendingToServer`의 서버 왕복(모바일 네트워크라 수 초 걸릴 수 있음) 도중에도
  /// `_creditDistance`로 계속 쌓이는데, 그때 0으로 리셋하면 왕복 중 쌓인 델타가 서버엔 안 갔는데
  /// 로컬에선 지워져 유실된다.
  Future<void> _consumePendingServerSync(int sentDelta, bool sentMock) async {
    final stored =
        int.tryParse(await _settings.getValue(_pendingServerSyncDeltaKey) ?? '0') ??
        0;
    final remaining = stored - sentDelta;
    await _settings.setValue(
      _pendingServerSyncDeltaKey,
      '${remaining < 0 ? 0 : remaining}',
    );
    // mock 플래그는 best-effort 감사 신호라(다음 탐지 때 다시 세워짐) 보낸 경우 내린다.
    if (sentMock) {
      await _settings.setValue(_pendingMockDetectedKey, 'false');
    }
  }

  /// 주기 타이머 + 백그라운드 전환/복귀 + 부화 시도 직전(egg_inventory_screen.dart)이 호출 —
  /// 갱신 시각을 stamp하고 미전송 델타를 서버로 flush.
  Future<void> syncNow() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _settings.setValue(
        _lastSyncedAtKey,
        DateTime.now().toIso8601String(),
      );
      await _flushPendingToServer();
    } catch (e) {
      developer.log(
        '거리 서버 flush 실패(다음 시도 때 재시도): $e',
        name: 'DistanceTrackerService',
      );
    } finally {
      _flushing = false;
    }
  }

  /// 게스트면 조용히 무시(서버에 상태 자체가 없으므로). 실패해도 예외를 삼킴 — 다음 시도 때
  /// pending이 그대로 남아 따라잡힘.
  Future<void> _flushPendingToServer() async {
    if (_serverBusy) return;
    final session = _authSession;
    if (session == null || !session.isLoggedIn) return;

    final storedDelta = await _settings.getValue(_pendingServerSyncDeltaKey);
    final pendingDelta = int.tryParse(storedDelta ?? '0') ?? 0;
    final pendingMockDetected =
        (await _settings.getValue(_pendingMockDetectedKey)) == 'true';
    if (pendingDelta <= 0 && !pendingMockDetected) return;

    _serverBusy = true;
    try {
      // Part 1(Document/temp.md) — 서버엔 파트너 개념이 없어 이번에 거리를 적립할 파트너 알 id를
      // 그 시점 로컬 상태에서 조회해 함께 보냄.
      final partnerEggIds = await _eggRepository.getPartnerEggIds();
      final api = DistanceSyncApi(AuthorizedApiClient(session));
      final serverDistances = await api.sync(
        pendingDelta,
        mockDetected: pendingMockDetected,
        partnerEggIds: partnerEggIds,
      );
      await _consumePendingServerSync(pendingDelta, pendingMockDetected);
      // Part 3-A — 서버가 속도 클램프/mock 스킵으로 조정한 최종 누적값을 로컬 파트너 알에 반영
      // (회원은 서버 authoritative). 부화 진행도 바가 "실제로 부화 때 인정될 값"을 보여줌.
      await _eggRepository.applyServerDistances(serverDistances);
    } catch (e) {
      developer.log(
        '거리 서버 동기화 실패(다음 시도 때 재시도): $e',
        name: 'DistanceTrackerService',
      );
    } finally {
      _serverBusy = false;
    }
  }

  // ── 5-c: GPS 앵커 조정 (map_screen이 읽고 내림) ──────────────────────────────
  bool get gpsAnchorPendingReset => _gpsAnchorPendingReset;
  DateTime? get lastResumedAt => _lastResumedAt;
  void clearGpsAnchorPendingReset() => _gpsAnchorPendingReset = false;

  void dispose() {
    _serverFlushTimer?.cancel();
    _serverFlushTimer = null;
    _pedometerSub?.cancel();
    _pedometerSub = null;
  }
}
