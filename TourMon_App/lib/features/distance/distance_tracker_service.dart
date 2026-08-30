import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

import '../../config/game_config.dart';
import '../../data/app_settings_repository.dart';
import '../../data/daily_distance_repository.dart';
import '../../data/day_key.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../egg/egg_repository.dart';
import 'distance_sync_api.dart';

/// Health Connect 전환(Document/temp.md "통합 결정") — 4단계 걸음수 측정 → 파트너 알 누적을
/// 대체. `pedometer`의 raw 센서 스트림 대신, 앱이 완전히 꺼져 있어도 OS가 상시 기록해두는
/// Health Connect 레코드를 이 서비스의 주기 타이머(GameConfig.distanceServerSyncInterval)마다
/// 적립한다.
///
/// **"하루 누적 스냅샷" 방식(2026-08-27 전환)** — 매 동기화마다 오늘 하루 전체를 다시 조회해
/// "오늘 총량"을 구하고, 지금까지 반영해둔 baseline(`_todayAppliedMetersKey`)과의 차이만 적립한 뒤
/// baseline을 오늘 총량으로 갱신한다. 실기기 확인 결과 삼성 헬스는 STEPS를 잘게 나눠 쓰지 않고
/// 하루 전체(자정~23:59)를 스팬으로 하는 레코드 하나를 계속 upsert하는 방식이라, 예전처럼
/// `[마지막 동기화 시각, now)` 좁은 창으로만 조회하면 그 레코드를 거의 못 잡고(창이 짧을수록
/// 특히) 커서가 계속 전진해버려 놓친 구간이 영영 복구가 안 되는 문제가 있었음(`daily_distance`/
/// `pending_server_sync_delta_meters`가 몇 주째 전혀 안 쌓이는 걸로 발견).
///
/// 매번 하루 전체를 재조회하는 방식으로 바꿨어도 **조회 시작 시각을 리셋 경계(새벽 4시)로 잡으면
/// 여전히 실패한다** — 실측 확인(2026-08-27, `readRecords` 실제 로그로 재현): Health Connect는
/// **레코드 자체의 시작 시각이 조회 구간 시작 시각보다 이르면 그 레코드를 통째로 안 돌려줌**
/// (부분 겹침만으론 안 잡힘). 삼성 헬스 레코드는 자정(리셋 경계보다 4시간 이름)부터 시작하므로,
/// 조회를 리셋 경계부터로 좁히면 항상 통째로 누락됨. 그래서 [_safeQueryStart]로 자정보다 살짝
/// (30분) 더 여유 있게 조회 시작 시각을 앞당기고, 결과는 [splitByResetDay]로 게임 날짜별로 정확히
/// 재배분한다(`_queryStepsByDay`). 여유를 하루치로 크게 두면 전날(이미 처리된 날짜) 레코드까지
/// 다시 잡혀 이중 집계되는 버그가 있었어서(2026-08-27 발견, `_safeQueryStart` 문서 참고) 자정
/// 바로 앞 30분으로만 제한. 이 방식은 Health Connect가 데이터를 언제/어떻게 쓰든(하루 1개로
/// 몰아쓰든, 뒤늦게 upsert하든) 다음 동기화 때 다시 전체를 읽어 diff를 내므로 구조적으로 유실이
/// 불가능해짐(self-healing). 날짜가 바뀐 시점(닫힌 지난 날짜)에 한해서만 델타 그대로 한 번
/// 캐치업 — 이미 닫힌 날짜는 더 이상 upsert가 안 되므로 델타 합산 방식이어도 안전함.
///
/// `DISTANCE_DELTA` 대신 `STEPS`를 조회함 — 삼성 헬스가 Health Connect에 STEPS만 동기화하고
/// DISTANCE_DELTA는 안 써서(실기기 확인, 2026-08-26) DISTANCE_DELTA 기준으로는 삼성 헬스
/// 사용자의 거리 적립이 아예 안 되는 문제가 있었음. STEPS를 GameConfig.stepsToMetersFactor로
/// 직접 환산해 거리로 저장/표시하되, 저장 계층(daily_distance_repository 등)은 그대로 "거리"
/// 단위를 유지 — 환산은 이 서비스 안에서만 일어남.
///
/// mock-location 감지(temp.md "중요한 역설" — 거리 방식은 흔들개보다 진입장벽 낮은 GPS 스푸핑에
/// 취약해지므로 필수 구성요소로 격상됨) — 백그라운드("항상 허용") 위치 권한은 온보딩 마찰 이유로
/// 배제 확정이라, 이 서비스의 동기화 주기마다 `Geolocator.getCurrentPosition()`을 1회 호출해
/// `Position.isMocked`(Android)를 확인하는 방식으로 구현(지도 화면이 열려있지 않아도 앱이
/// 포그라운드인 동안은 감지됨 — 이 한계는 temp.md가 이미 받아들인 전제와 일치).
///
/// 6단계 Phase 5 — 로그인 상태면 로컬 누적과 별개로 서버에도 델타를 동기화(init_plan.md 4-3
/// "걸음수 서버 동기화"). 로컬 sqlite는 그대로 진행도 표시의 기준으로 남고(변경 없음), 서버는
/// 주기적으로 델타만 받아 자기 사본에 누적 — 목표 거리 달성 판정(부화 승인)의 근거가 됨.
class DistanceTrackerService {
  DistanceTrackerService._();
  static final DistanceTrackerService instance = DistanceTrackerService._();

  // 더 이상 조회 커서로는 안 쓰지만(하루 누적 스냅샷 방식 전환), 디버그 뷰어에서 "마지막으로
  // 동기화 시도한 시각" 진단용으로는 계속 갱신.
  static const _lastSyncedAtKey = 'distance_last_synced_at';
  // 오늘 몫 중 이미 daily_distance/파트너알/pending-server-sync에 반영 완료한 누적 미터(baseline).
  // 오늘 총량과의 차이(diff)만 다음 적립에 쓰기 위한 기준점 — [today_distance_applied_day_key]와
  // 항상 같이 갱신됨.
  static const _todayAppliedMetersKey = 'today_distance_applied_meters';
  // 위 baseline이 어느 게임 날짜([resetDayKey]) 것인지 — 날짜가 바뀌면 지난 날짜를 한 번 캐치업하고
  // baseline을 0으로 리셋.
  static const _todayAppliedDayKeyKey = 'today_distance_applied_day_key';
  // 서버로 아직 못 보낸 델타 누적치(meters) — 동기화 성공 시에만 0으로 리셋하고, 실패하면 그대로
  // 둬서 다음 시도 때 따라잡힘. mock-location 플래그도 같이 들고 있다가 다음 서버 호출 때 함께
  // 실어보냄 — 그래야 거리가 0인 구간에서 mock만 감지된 경우도 서버 감사 로그에 남길 수 있음.
  static const _pendingServerSyncDeltaKey = 'pending_server_sync_delta_meters';
  static const _pendingMockDetectedKey = 'pending_server_sync_mock_detected';

  final _settings = const AppSettingsRepository();
  final _eggRepository = const EggRepository();
  final _dailyDistanceRepository = const DailyDistanceRepository();
  final _health = Health();

  AuthSession? _authSession;
  Timer? _syncTimer;
  bool _starting = false;
  bool _syncing = false;

  /// [requestPermissionIfNeeded]가 false면 이미 권한이 있을 때만 조용히 시작하고, 없으면 OS
  /// 권한 다이얼로그/Health Connect 설치 유도 없이 그냥 대기(호출한 쪽에서 나중에 다시 [start]를
  /// 부르면 그때 재확인). 앱 실행 직후(main.dart)는 항상 false로 호출 — "게스트/회원 동일하게
  /// 파트너 알을 처음 설정하는 시점에 요청, 앱 실행 시점엔 요청 안 함"(Document/temp.md 미결 사항
  /// 결정, 지도도 보기 전에 건강 데이터 동의부터 뜨면 이탈 위험이 크다는 판단). 파트너 알을 처음
  /// 지정하는 순간(`EggInventoryScreen._onPartnerToggled`)엔 true로 호출해 그때 실제로 요청.
  ///
  /// 반환값: 동기화 서비스가 도는 상태(권한이 있어 파트너 알 적립이 가능)면 true, 권한 거부/
  /// 미설치로 못 시작했으면 false. 이미 돌고 있던 경우(재호출) true. 호출부가 이 값으로 "권한
  /// 없으니 방금 건 파트너 지정을 되돌린다" 같은 판단을 한다.
  Future<bool> start(AuthSession authSession, {bool requestPermissionIfNeeded = true}) async {
    _authSession = authSession;
    if (_starting || _syncTimer != null) return true;
    _starting = true;
    try {
      _health.configure();
      final granted = await _ensurePermission(requestIfNeeded: requestPermissionIfNeeded);
      if (!granted) {
        if (requestPermissionIfNeeded) {
          developer.log('Health Connect 권한/설치 필요 — 파트너 알 진행 불가', name: 'DistanceTrackerService');
        }
        return false;
      }
      _syncTimer = Timer.periodic(GameConfig.distanceServerSyncInterval, (_) => syncNow());
      unawaited(syncNow());
      return true;
    } finally {
      _starting = false;
    }
  }

  /// 부작용 없이(설치/권한 팝업 유도 안 함) 현재 Health Connect 권한이 이미 있는지만 확인 —
  /// 파트너 알을 처음 지정하기 전에 "이제 곧 Health Connect 설치/권한 화면으로 넘어갑니다" 안내를
  /// 띄울지 판단하는 용도(egg_inventory_screen.dart). 이미 권한이 있으면 안내 없이 바로 진행해도
  /// 됨 — 어차피 아무 팝업도 안 뜸(실기기 확인, Document/temp.md 참고: 예고 없이 갑자기 Play
  /// Store 설치 화면으로 넘어가서 당황스러웠던 문제).
  Future<bool> hasPermission() => _ensurePermission(requestIfNeeded: false);

  /// 마지막으로 거리 데이터를 실제로 갱신한 시각([syncNow]가 오늘 스냅샷 반영을 끝낸 시점, 또는
  /// 최초 baseline 저장 시점). UI가 "N분 전 기준" 같은 상대 시각을 보여줘서, 화면의 거리 수치가
  /// 실시간이 아니라 [GameConfig.distanceServerSyncInterval] 주기로만 갱신된다는 것(배터리 절약
  /// 목적)을 사용자에게 알리는 용도. 아직 한 번도 동기화된 적 없으면 null.
  Future<DateTime?> lastSyncedAt() async {
    final raw = await _settings.getValue(_lastSyncedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> _ensurePermission({required bool requestIfNeeded}) async {
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        if (!requestIfNeeded) return false;
        // 미설치/업데이트 필요 — Play Store로 유도만 하고 이번 실행은 종료(다음 실행 때 재확인).
        await _health.installHealthConnect();
        return false;
      }
    }
    const types = [HealthDataType.STEPS];
    var granted = await _health.hasPermissions(types) ?? false;
    if (!granted) {
      if (!requestIfNeeded) return false;
      try {
        granted = await _health.requestAuthorization(types);
      } catch (e) {
        developer.log('Health Connect 권한 요청 실패: $e', name: 'DistanceTrackerService');
        return false;
      }
      if (!granted) return false;
    }

    // READ_HEALTH_DATA_IN_BACKGROUND(백그라운드 STEPS 읽기, Android 15+에만 존재)는 요청하지
    // 않는다 — Health Connect 심사에서 가장 까다롭게 보는 권한인데, 얻는 건 "앱이 백그라운드일 때도
    // 주기 타이머/전환 시 동기화가 성공"하는 것뿐이고, 그건 없어도 포그라운드 복귀(main.dart의
    // `resumed`) 때 syncNow()가 [마지막 반영, now) 하루 전체를 재조회해 유실 없이 따라잡는다
    // (self-healing). Android 14 이하는 애초에 이 권한이 없어 이미 이 방식으로 동작 중이었고,
    // 15+도 같은 방식으로 통일(2026-08-29 결정, study_folder/4-1). 백그라운드에서의 STEPS 읽기는
    // RemoteException으로 실패하지만 syncNow()의 catch가 삼키므로 무해.
    return true;
  }

  /// 주기 타이머 + 백그라운드 전환/복귀 시(main.dart) + 부화 시도 직전(egg_inventory_screen.dart)
  /// 셋 다 이걸 호출. "오늘"(리셋 경계 기준) 전체를 다시 조회해 지금까지 반영해둔 baseline과의
  /// 차이만 로컬 파트너알/일별 히스토리에 적립하고, 로그인 상태면 서버에도 동기화. 날짜가 바뀐
  /// 경우엔 닫힌 지난 날짜(들)를 먼저 한 번 캐치업.
  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final now = DateTime.now();
      final todayKey = resetDayKey(now);
      final todayStart = resetDayStart(now);
      final storedDayKey = await _settings.getValue(_todayAppliedDayKeyKey);

      if (storedDayKey == null) {
        // 최초 실행 — temp.md 미결 사항 결정대로 과거 데이터 백필 없이 지금부터 새로 시작. 지금
        // 시점의 오늘 누적치를 baseline으로만 저장(반영은 안 함) — 이후 늘어난 만큼만 적립됨.
        final byDay = await _queryStepsByDay(_safeQueryStart(todayStart), now);
        final currentTotal = byDay[todayKey] ?? 0;
        await _settings.setValue(_todayAppliedDayKeyKey, todayKey);
        await _settings.setValue(_todayAppliedMetersKey, '$currentTotal');
        await _settings.setValue(_lastSyncedAtKey, now.toIso8601String());
        return;
      }

      var storedApplied = double.tryParse(await _settings.getValue(_todayAppliedMetersKey) ?? '0') ?? 0;

      if (storedDayKey != todayKey) {
        // 날짜가 바뀜 — 닫힌 지난 날짜(들)를 한 번만 캐치업. [storedDayKey](방금까지 "오늘"이던 날)는
        // 이미 storedApplied만큼 부분 반영이 돼 있으므로 그 날짜만 diff로, 그 사이에 앱을 전혀 안 켜서
        // 한 번도 반영 안 된 날짜(들)는 전체 총량으로 반영. 이후 정기 동기화에서 다시 이 날짜들을
        // 처리하지 않음 — todayKey 아닌 키는 여기서만 처리.
        final closedByDay = await _queryStepsByDay(
          _safeQueryStart(resetDayStartFromKey(storedDayKey)),
          todayStart,
        );
        var closedDeltaMeters = 0.0;
        for (final entry in closedByDay.entries) {
          // todayKey 항목은 오늘 자정부터 시작하는 레코드가 이 구간(끝=todayStart) 안에도 걸쳐서
          // 비례 배분된 결과일 뿐 — 오늘 몫은 바로 아래 "오늘 몫" 처리에서 정확한 구간으로 다시
          // 계산되므로 여기서 건드리면 이중 집계됨.
          if (entry.key == todayKey) continue;
          final baseline = entry.key == storedDayKey ? storedApplied : 0;
          final dayDelta = entry.value - baseline;
          if (dayDelta <= 0) continue;
          await _dailyDistanceRepository.addDistanceForDay(entry.key, dayDelta);
          closedDeltaMeters += dayDelta;
        }
        if (closedDeltaMeters > 0) {
          final roundedMeters = closedDeltaMeters.round();
          await _eggRepository.addDistanceToPartners(roundedMeters);
          await _addPendingServerSync(roundedMeters, false);
        }
        storedApplied = 0;
        await _settings.setValue(_todayAppliedDayKeyKey, todayKey);
        await _settings.setValue(_todayAppliedMetersKey, '0');
      }

      // 오늘 몫 — 항상 [안전 시작 시각, now) 전체를 다시 조회해 오늘 총량과 baseline의 차이만
      // 적립. Health Connect가 하루 전체를 하나로 몰아서 upsert하는 소스(삼성 헬스 등)에도 안전하게
      // 대응(_queryStepsByDay/_safeQueryStart 참고). 이 호출에서 todayKey 아닌 날짜가 같이 잡혀도
      // 무시 — 그 날짜는 위 캐치업 분기에서만 한 번 처리됨.
      final byDay = await _queryStepsByDay(_safeQueryStart(todayStart), now);
      final todayTotal = byDay[todayKey] ?? 0;
      final deltaMeters = todayTotal - storedApplied;

      final mockDetected = await _checkMockLocation();

      if (deltaMeters > 0) {
        await _dailyDistanceRepository.addDistanceForDay(todayKey, deltaMeters);
        final roundedMeters = deltaMeters.round();
        await _eggRepository.addDistanceToPartners(roundedMeters);
        await _addPendingServerSync(roundedMeters, mockDetected);
        // 절대값 total로 저장(누적 add가 아님) — float 오차가 반복 누적되는 것을 방지.
        await _settings.setValue(_todayAppliedMetersKey, '$todayTotal');
      } else if (mockDetected) {
        // 이번엔 새로 늘어난 거리가 없었지만 mock이 감지됐으면 그 사실만이라도 다음 서버 호출에 실어보냄.
        await _addPendingServerSync(0, mockDetected);
      }
      // deltaMeters <= 0인 경우(HC 총량이 일시적으로 줄어드는 이례적 케이스) baseline을 그대로 둬서
      // 다음 동기화 때 같은 기준으로 재시도됨.

      await _settings.setValue(_lastSyncedAtKey, now.toIso8601String());
      await _flushPendingToServer();
    } catch (e) {
      developer.log('거리 동기화 실패(다음 시도 때 재시도): $e', name: 'DistanceTrackerService');
    } finally {
      _syncing = false;
    }
  }

  /// [gameDayBoundary](리셋 경계 시각, KST 4시)를 실제 Health Connect 조회 시작 시각으로 안전하게
  /// 앞당김 — 실기기 확인(2026-08-27) 결과 Health Connect의 `readRecords`는 **레코드 자체의 시작
  /// 시각이 조회 구간 시작 시각보다 이른 레코드를 통째로 안 돌려줌**. 삼성 헬스는 걸음수를 자정
  /// (00:00, 리셋 경계보다 4시간 이름)부터 시작하는 하루 통짜 레코드 하나로 계속 upsert하는데,
  /// 조회를 리셋 경계(4시)부터로 좁히면 이 레코드가 매번 통째로 누락됨(daily_distance/
  /// pending_server_sync_delta_meters가 몇 주째 전혀 안 쌓이던 근본 원인).
  ///
  /// 자정에서 30분만 더 앞당김 — 리셋 경계와 자정 사이 4시간에 비해 충분히 여유 있지만, **하루를
  /// 넘겨서 전날 자정까지 침범하지 않도록 의도적으로 작게 잡음**. `syncNow()`의 날짜 롤오버
  /// 캐치업 분기가 [storedDayKey]의 레코드만 잡아야 하는데, 여유를 하루치로 뒀다가 전날(이미 그
  /// 전 전환에서 다 처리된 날짜) 레코드까지 다시 잡아 이중 집계되는 버그가 있었음(2026-08-27
  /// 발견) — 그래서 리셋 경계~자정 사이(4시간)보다는 훨씬 짧게, 전날 자정까지는 절대 안 닿는
  /// 폭으로 제한.
  DateTime _safeQueryStart(DateTime gameDayBoundary) => gameDayBoundary
      .subtract(const Duration(hours: GameConfig.dailyResetHourKst))
      .subtract(const Duration(minutes: 30));

  /// [start, end) 구간의 Health Connect STEPS 레코드를 조회해 [splitByResetDay]로 게임 날짜별
  /// 거리(m) 합계로 배분 — 오늘 스냅샷 조회와 닫힌 날짜 캐치업 조회 양쪽에서 재사용.
  Future<Map<String, double>> _queryStepsByDay(DateTime start, DateTime end) async {
    if (!end.isAfter(start)) return {};
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.STEPS],
      startTime: start,
      endTime: end,
      // 수동 입력 데이터는 제외(temp.md "메타데이터로 감지해 제외 가능") — 자동/능동 기록만 인정.
      recordingMethodsToFilter: const [RecordingMethod.manual],
    );
    final result = <String, double>{};
    for (final point in points) {
      final value = point.value;
      if (value is! NumericHealthValue) continue;
      final meters = value.numericValue.toDouble() * GameConfig.stepsToMetersFactor;
      for (final entry in splitByResetDay(point.dateFrom, point.dateTo, meters)) {
        result[entry.key] = (result[entry.key] ?? 0) + entry.value;
      }
    }
    return result;
  }

  /// 동기화 시점에 mock-location(가짜 GPS)이 켜져 있는지 1회 확인 — Health Connect 거리 자체는
  /// GPS를 안 쓰지만, 지도 화면이 이미 쓰고 있는 "사용 중일 때만" 위치 권한을 그대로 재사용해서
  /// 별도 권한 추가 없이 확인 가능(temp.md "중요한 역설" 절 참고). 위치 권한이 없거나 조회
  /// 실패하면 mock 여부를 판단할 수 없으므로 false(감지 안 됨) 취급 — 이 기능의 목적은 명백한
  /// 스푸핑을 잡아내는 것이지, 권한 미허용 자체를 치팅으로 간주하는 게 아님.
  Future<bool> _checkMockLocation() async {
    if (!Platform.isAndroid) return false;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.lowest),
      );
      return position.isMocked;
    } catch (e) {
      developer.log('mock-location 확인 실패(감지 안 됨으로 처리): $e', name: 'DistanceTrackerService');
      return false;
    }
  }

  Future<void> _addPendingServerSync(int deltaMeters, bool mockDetected) async {
    final stored = await _settings.getValue(_pendingServerSyncDeltaKey);
    final current = int.tryParse(stored ?? '0') ?? 0;
    await _settings.setValue(_pendingServerSyncDeltaKey, '${current + deltaMeters}');
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

  /// 게스트면 조용히 무시(서버에 상태 자체가 없으므로). 실패해도 예외를 삼킴 — 다음 시도 때
  /// pending이 그대로 남아 따라잡힘.
  Future<void> _flushPendingToServer() async {
    final session = _authSession;
    if (session == null || !session.isLoggedIn) return;

    final storedDelta = await _settings.getValue(_pendingServerSyncDeltaKey);
    final pendingDelta = int.tryParse(storedDelta ?? '0') ?? 0;
    final pendingMockDetected = (await _settings.getValue(_pendingMockDetectedKey)) == 'true';
    if (pendingDelta <= 0 && !pendingMockDetected) return;

    try {
      // Part 1(Document/temp.md) — 서버엔 파트너 개념이 없어 이번에 거리를 적립할 파트너 알 id를
      // 그 시점 로컬 상태에서 조회해 함께 보냄. 실패~재시도 사이 파트너가 바뀌면 델타가 새 파트너로
      // 가는데, 로컬 addDistanceToPartners 동작과 근사하고 최대 1 sync 간격 분량이라 무시 가능.
      final partnerEggIds = await _eggRepository.getPartnerEggIds();
      final api = DistanceSyncApi(AuthorizedApiClient(session));
      final serverDistances = await api.sync(
        pendingDelta,
        mockDetected: pendingMockDetected,
        partnerEggIds: partnerEggIds,
      );
      await resetPendingServerSyncDelta();
      // Part 3-A — 서버가 속도 클램프/ mock 스킵으로 조정한 최종 누적값을 로컬 파트너 알에 반영
      // (회원은 서버 authoritative). 이로써 부화 진행도 바가 "실제로 부화 때 인정될 값"을 보여줌.
      await _eggRepository.applyServerDistances(serverDistances);
    } catch (e) {
      developer.log('거리 서버 동기화 실패(다음 시도 때 재시도): $e', name: 'DistanceTrackerService');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
