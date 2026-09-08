import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../config/debug_config.dart';
import '../../config/map_config.dart';
import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../config/tourism_config.dart';
import '../../data/tourism_spot_repository.dart';
import '../../l10n/app_localizations.dart';
import '../consent/location_consent_dialog.dart';
import '../debug/debug_db_viewer_screen.dart';
import '../distance/debug_activity_permission_button.dart';
import '../distance/debug_distance_injector_button.dart';
import '../distance/distance_tracker_service.dart';
import '../egg/debug_add_egg_button.dart';
import '../egg/egg_repository.dart';
import '../egg/welcome_egg.dart';
import '../egg/welcome_gift_dialog.dart';
import '../onboarding/onboarding_screen.dart';
import 'location_permission.dart';
import 'partner_egg_progress_box.dart';
import 'quick_actions_box.dart';
import 'tourism_spot.dart';
import 'tourism_spot_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _tileProvider = FMTCTileProvider(
    stores: const {
      MapConfig.tileCacheStoreName: BrowseStoreStrategy.readUpdateCreate,
    },
  );
  final _mapController = MapController();
  final _tourismSpotRepository = const TourismSpotRepository();
  final _eggRepository = const EggRepository();
  static const _distance = Distance();

  // 테스트용 유형별 마커 이미지(Resource 폴더에서 받은 원본을 36폭 기준으로 리사이즈해 assets/markers/에
  // 넣음) — 8개 카테고리 전부 적용됨.
  static const _categoryMarkerAssets = <int, String>{
    12: 'assets/markers/tourist.png',
    14: 'assets/markers/cultural.png',
    15: 'assets/markers/festival.png',
    25: 'assets/markers/travel_course.png',
    28: 'assets/markers/leports.png',
    32: 'assets/markers/accommodation.png',
    38: 'assets/markers/shopping.png',
    39: 'assets/markers/restaurant.png',
  };

  List<TourismSpot> _spots = [];
  // 마커 쿨타임 배지(Document/temp.md "마커 쿨타임 배지") — 오늘 이미 획득한 스팟 id 전체를 한 번에
  // Set으로 들고 있다가 마커 빌드 시 .contains()만 동기적으로 체크(스팟마다 쿼리 하나씩 부르는 대신).
  Set<int> _acquiredTodaySpotIds = {};
  LatLng? _lastQueryCenter;
  double _lastQueryRadiusMeters = 0;
  Timer? _debounceTimer;

  // 로컬 캐시(tourism_spots)가 비어있는 최초 실행에는 이게 끝날 때까지 블로킹 — 마커 없이는 지도
  // 자체가 의미 없음(Document/temp.md "tour_spot 로컬 캐싱" 2번). 이미 캐시가 있으면 안 씀(그때는
  // 스테일 체크 후 백그라운드로만 재동기화, _maybeBackgroundResync 참고).
  bool _isInitialSyncing = false;
  String? _initialSyncError;

  // 팔로우 모드(카메라 자동 추적) 상태 — Document/temp.md "지도 카메라 자동 추적" 계획 참고.
  // 기본값 false — 위치 추적은 동의+권한이 확보돼야 시작하고(_startLocationTracking /
  // _maybeAutoStartTracking), 그 전까지는 파란 점도 FAB "추적 중" 표시도 없다. 지도를 보기 전에
  // OS 권한 팝업을 띄우지 않는 프로젝트의 just-in-time 결정과 일관(main.dart의 Health Connect
  // 처리, onboarding_screen.dart 주석, init_plan.md, study_folder/2-4 #3).
  bool _followMode = false;
  // CurrentLocationLayer의 alignPositionOnUpdate(AlignOnUpdate.always)는 GPS 갱신마다 카메라를
  // 위치로 재중심시키긴 하지만, 초기 상태(initialCenter=서울시청 부근)에서는 실제 사용자 위치로
  // 한 번 옮겨줘야 이후 추적이 그 위치를 유지한다. 팔로우가 켜진 뒤 첫 GPS 픽스 딱 한 번만
  // _toggleFollowMode()의 이동 로직처럼 직접 카메라를 사용자 위치로 옮김(_positionSub 리스너 참고).
  // 줌 레벨은 건드리지 않는다(2026-08-30, 사용자 요청 — FAB는 "현재 위치로 이동"만, 줌 변경 없음).
  bool _hasCenteredOnFirstFix = false;
  bool _isSpeeding = false;
  // 인천/서울 서비스 지역 밖에 있는지 — 밖이면 팔로우 모드로 카메라를 그쪽으로 옮기지 않고(타일이
  // 없어 회색 화면만 보임, Document/temp.md 참고) 안내 메시지만 1회 띄움.
  bool _isOutOfServiceArea = false;
  DateTime? _lastPositionAt;

  // GPS 주 경로 거리 적립(Document/temp.md)의 직전 기준점 — haversine 세그먼트 계산용. 픽스
  // 타임스탬프(_lastPositionAt은 벽시계라 속도 판정 전용, 이쪽은 Position.timestamp)와 짝을
  // 이뤄 5-b 클램프/5-c Stale Fix 방어에 쓴다.
  LatLng? _distanceAnchor;
  DateTime? _distanceAnchorAt;

  // GPS 스트림을 CurrentLocationLayer와 우리 쪽(속도 판정 + 알 획득 반경 원 표시)이 하나만 공유 —
  // defaultPositionStreamSource()는 CurrentLocationLayer가 positionStream 없이 쓸 때 내부적으로
  // 쓰는 것과 동일한 소스(권한 요청/거부 플로우 포함, broadcast)라 이걸 그대로 주입하면 패키지 기본
  // 동작을 잃지 않으면서 구독을 하나로 합칠 수 있음.
  //
  // initState에서 무조건 구독하지 않는다 — 동의+권한이 확보된 뒤 _subscribeToPositionStream()에서
  // 생성/구독하고, 세션 중 권한이 회수되면 _teardownLocationTracking()에서 정리한다. 구독 수명은
  // "위치 사용 가능 상태"에 묶이고, _followMode(카메라 재중심 여부)와는 독립이다 — 사용자가 팔로우만
  // 꺼도 구독은 살아서 알 획득 반경 원/속도 판정은 계속 동작.
  Stream<LocationMarkerPosition?>? _markerPositionStream;
  StreamSubscription<Position?>? _positionSub;
  // 알 획득 반경 원(아래 CircleLayer)의 중심 — 모든 사용자에게 상시 표시(2026-08-26, 사용자 요청).
  // ValueNotifier로 들고 있다가 CircleLayer만 ValueListenableBuilder로 감싸서, GPS 픽스마다
  // setState로 지도 화면 전체(FlutterMap + 마커 클러스터 재계산)를 리빌드하지 않도록 함
  // (study_folder/2-4 — 매 틱 setState 회귀 수정). 파란 점은 CurrentLocationLayer가 자기
  // 내부 구독으로 갱신하므로 우리 setState와 무관.
  final ValueNotifier<LatLng?> _currentPositionNotifier = ValueNotifier(null);

  AlignOnUpdate get _alignPositionOnUpdate =>
      _followMode && !_isSpeeding && !_isOutOfServiceArea
      ? AlignOnUpdate.always
      : AlignOnUpdate.never;

  @override
  void initState() {
    super.initState();
    _ensureTourismData();
    // 앱 최초 실행이면 핵심 루프 안내(마커→알→파트너→걷기→부화)를 한 번 보여줌 — 첫 프레임
    // 직후에 띄워서 지도는 뒤에서 로딩되게 함. 이미 본 사용자는 아무 일도 안 일어남. 온보딩을 닫으면
    // 이어서 웰컴 알을 지급하고(이 기기에서 아직 안 받았으면) "선물이 왔어요" 팝업을 띄운다 —
    // 네트워크 실패면 조용히 넘어가고 다음 실행에 재시도(welcome_egg.dart).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showOnboardingIfNeeded(context);
      if (!mounted) return;
      final gifted = await claimWelcomeEggIfNeeded(context);
      if (gifted != null && mounted) {
        await showWelcomeGiftDialog(context, gifted);
      }
    });
    // 이미 위치 동의를 마쳤고 권한도 허용돼 있으면 조용히 위치 추적 재개(OS 팝업 안 뜸). 첫 실행/
    // 미동의/권한 거부 상태면 아무것도 안 하고 FAB 탭(_startLocationTracking)을 기다린다.
    unawaited(_maybeAutoStartTracking());
    // 지도를 보며 걷는 동안 화면이 꺼지지 않게 함(2026-08-26, 사용자 요청) — 이 화면에 있는
    // 동안만 적용되고 다른 화면으로 나가거나 앱이 백그라운드로 가면 dispose()에서 자동으로
    // 풀림. 도감/알 보관함/마이페이지 등 읽기 전용 화면까지 켜둘 이유는 없어서 지도 화면 범위로
    // 한정(배터리 소모가 실제로 커지므로).
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _positionSub?.cancel();
    _currentPositionNotifier.dispose();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  // 동의가 이미 저장됐고 위치 권한도 이미 허용돼 있을 때만 조용히 추적 시작 — checkPermission()은
  // 팝업을 띄우지 않으므로(요청은 requestPermission()) 첫 실행/미동의/거부 상태에서는 여기서
  // 아무 UI도 뜨지 않는다. 재방문 유저는 예전처럼 지도를 열자마자 파란 점이 뜨고 팔로우가 켜진다.
  Future<void> _maybeAutoStartTracking() async {
    if (!await hasStoredLocationConsent()) return;
    final permission = await Geolocator.checkPermission();
    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted || !mounted || _positionSub != null) return;
    _subscribeToPositionStream();
    setState(() => _followMode = true);
  }

  // FAB로 팔로우를 켤 때의 진입점 — 인앱 위치 동의 → 위치 서비스 → OS 권한을 순서대로 게이트하고
  // (ensureLocationReady, 알 획득 흐름과 공유), 통과하면 공유 GPS 구독을 시작한 뒤 현재 위치로
  // 카메라를 1회 이동시키고 팔로우를 켠다. 각 실패 지점마다 스낵바로 안내.
  Future<void> _startLocationTracking() async {
    if (_positionSub != null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final gate = await ensureLocationReady(context);
    if (!mounted) return;
    if (gate != LocationGateResult.granted) {
      final message = locationGateMessage(l10n, gate);
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    try {
      _subscribeToPositionStream();
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      if (MapConfig.serviceAreaBounds.contains(point)) {
        // 구독의 첫 픽스가 리스너에서 또 이동시키지 않도록 플래그를 여기서 세움.
        _hasCenteredOnFirstFix = true;
        // 줌은 현재 값 유지 — 현재 위치로 카메라만 옮김.
        _mapController.move(point, _mapController.camera.zoom);
        setState(() => _followMode = true);
      } else {
        // 서비스 지역 밖 — 팔로우는 안 켜지만 구독은 유지(안으로 들어오면 리스너가 처리).
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.outOfServiceAreaMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.genericErrorMessage(e.toString()))),
      );
    }
  }

  // 공유 GPS 구독 시작 — defaultPositionStreamSource()를 한 번만 만들어 우리 리스너(_onPositionFix)와
  // CurrentLocationLayer(_markerPositionStream)가 같이 쓴다(broadcast). onError는 세션 중 권한
  // 회수/서비스 중단 시 흘러들어옴(_handleLocationStreamError).
  void _subscribeToPositionStream() {
    if (_positionSub != null) return;
    final source = const LocationMarkerDataStreamFactory()
        .defaultPositionStreamSource();
    _positionSub = source.listen(
      _onPositionFix,
      onError: _handleLocationStreamError,
    );
    setState(() {
      _markerPositionStream = const LocationMarkerDataStreamFactory()
          .fromGeolocatorPositionStream(stream: source);
    });
  }

  void _teardownLocationTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _hasCenteredOnFirstFix = false;
    _lastPositionAt = null;
    _distanceAnchor = null;
    _distanceAnchorAt = null;
    _currentPositionNotifier.value = null;
    if (mounted) {
      setState(() {
        _markerPositionStream = null;
        _isSpeeding = false;
        _isOutOfServiceArea = false;
      });
    }
  }

  // 세션 중 설정에서 위치 권한이 회수되거나 위치 서비스가 꺼지면 defaultPositionStreamSource()가
  // 에러를 흘린다 — 구독을 정리하고 팔로우를 끈다. FAB는 다시 "꺼짐"으로 보이고, 누르면
  // _startLocationTracking()이 새로 게이트를 태운다.
  void _handleLocationStreamError(Object error, StackTrace stackTrace) {
    _teardownLocationTracking();
    if (!mounted) return;
    setState(() => _followMode = false);
    // 권한 회수 / 위치 서비스 중단 등 원인을 스트림 에러만으로 정확히 가르기 어려워 일반 문구 —
    // 다시 시작은 FAB 탭(→ _startLocationTracking 재게이트).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.locationTrackingStoppedMessage),
      ),
    );
  }

  void _onPositionFix(Position? position) {
    if (!mounted || position == null) return;
    final now = DateTime.now();
    final gap = _lastPositionAt == null
        ? null
        : now.difference(_lastPositionAt!);
    _lastPositionAt = now;
    // 화면을 끄고 이동했다가 다시 켰을 때처럼 오랜만에 재획득한 픽스는 OS가 보고하는
    // Position.speed 자체가 실제 이동과 무관하게 튀는 경우가 있어(실기기 확인, Document/temp.md
    // 참고) 이번 한 픽스만 속도 판정에서 제외 — "너무 빨라서..." 오탐 알림을 막기 위함.
    final gapTooLong = gap != null && gap > MapConfig.maxGpsFixGapForSpeedCheck;
    // gapTooLong(오랜만에 재획득한 첫 픽스)이면 이 픽스는 속도 판정에서 제외하고 직전 상태를
    // 그대로 유지 — false로 강제하면, 차량 주행 중(=_isSpeeding true) 화면을 껐다 켰을 때 이 한
    // 픽스에서 팔로우가 되살아나 카메라가 멀어진 현재 위치로 튐(다음 픽스에서 다시 정지). 도보
    // 중이었다면 계속 false라 "너무 빨라서..." 오탐 알림도 그대로 방지됨.
    final speeding = gapTooLong
        ? _isSpeeding
        : position.speed > MapConfig.maxWalkingSpeedMps;
    final outOfServiceArea = !MapConfig.serviceAreaBounds.contains(
      LatLng(position.latitude, position.longitude),
    );
    // 팔로우가 켜진 뒤 받는 첫 GPS 픽스 딱 한 번만 — 현재 위치로 카메라를 옮김(줌은 현재 값
    // 유지, 위 _hasCenteredOnFirstFix 선언부 주석 참고).
    if (_followMode && !outOfServiceArea && !_hasCenteredOnFirstFix) {
      _hasCenteredOnFirstFix = true;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    }
    // 실제로 바뀔 때만 setState — 매 GPS 틱마다 부르면 프로덕션 빌드에도 지도 화면 전체가
    // 상시 리빌드됨(temp.md 재검토 항목 참고). 알 획득 반경 원 위치는 _currentPositionNotifier로만
    // 갱신해서 CircleLayer 서브트리만 리빌드되게 함(study_folder/2-4).
    if (speeding != _isSpeeding || outOfServiceArea != _isOutOfServiceArea) {
      setState(() {
        _isSpeeding = speeding;
        _isOutOfServiceArea = outOfServiceArea;
      });
      if (outOfServiceArea) _showOutOfServiceAreaMessage();
    }
    _currentPositionNotifier.value = LatLng(
      position.latitude,
      position.longitude,
    );

    _accumulateGpsDistance(position);
  }

  // GPS 주 경로 거리 적립(Document/temp.md "거리 측정 이중화") — 좌표 간 이동 거리를 노이즈
  // 필터/클램프를 거쳐 DistanceTrackerService에 넘긴다. 구독 소유권은 이 화면에 유지하고,
  // 게임 로직(일별 히스토리/파트너 알/서버 동기화)은 서비스가 담당하는 절충안(temp.md 1번).
  void _accumulateGpsDistance(Position position) {
    final tracker = DistanceTrackerService.instance;
    final point = LatLng(position.latitude, position.longitude);
    final fixTime = position.timestamp;

    // 5-c — `paused`를 거친 뒤의 첫 픽스는 거리 적립을 스킵하고 앵커만 리셋한다(그 구간은
    // pedometer 보조 경로가 전담, 이중 집계 방지).
    if (tracker.gpsAnchorPendingReset) {
      final resumedAt = tracker.lastResumedAt;
      // Stale Fix — `resumed` 이전 타임스탬프 픽스는 OS가 즉시 내보낸 낡은 캐시 좌표일 수 있음.
      // 앵커로 삼지 않고 버린다(플래그는 유지 — 신선한 픽스가 와야 리셋).
      if (resumedAt != null && fixTime.isBefore(resumedAt)) return;
      _distanceAnchor = point;
      _distanceAnchorAt = fixTime;
      tracker.clearGpsAnchorPendingReset();
      return;
    }

    // 차량 이동 등 속도 초과 구간은 앵커만 리셋하고 적립하지 않음 — "걸어서 부화" 규칙과
    // 어긋나고, 속도가 정상으로 돌아올 때 큰 세그먼트가 튀는 것도 방지.
    if (_isSpeeding) {
      _distanceAnchor = point;
      _distanceAnchorAt = fixTime;
      return;
    }

    final anchor = _distanceAnchor;
    final anchorAt = _distanceAnchorAt;
    if (anchor == null || anchorAt == null) {
      _distanceAnchor = point;
      _distanceAnchorAt = fixTime;
      return;
    }

    // 5-a — 정확도가 나쁜(값이 큰) 픽스는 제외. 앵커는 유지해 다음 정상 픽스에서 이어감.
    if (position.accuracy > MapConfig.maxGpsAccuracyForDistanceMeters) return;

    final segment = _distance.as(LengthUnit.Meter, anchor, point);

    // 5-a — 정지 상태 drift: 최소 이동 거리 미만이면 무시(앵커 유지 → 실제로 이동했을 때
    // 그 지점부터 정상 적립).
    if (segment < MapConfig.minGpsDistanceDeltaMeters) return;

    final gapSeconds = fixTime.difference(anchorAt).inSeconds;
    // 시계 역전/동일 타임스탬프 — 클램프 근거가 없으므로 적립 없이 앵커만 갱신(temp.md 4번과 동일 결).
    if (gapSeconds <= 0) {
      _distanceAnchor = point;
      _distanceAnchorAt = fixTime;
      return;
    }

    // 5-b — 경과 시간 대비 물리적으로 가능한 거리로 클램프. 정상적인 "화면 껐다 켜고 그동안
    // 걸음"은 상한 안에 들어와 그대로 인정되고, GPS 튐/순간이동/mock 스푸핑은 상한에서 잘림.
    // gap은 시계/캐시 픽스 타임스탬프 조작으로 부풀릴 수 있어 절대 상한으로 캡(temp.md 4번의
    // elapsedMinutes 절대 상한과 같은 결).
    final cappedGapSeconds = gapSeconds < MapConfig.maxGpsDistanceGapSeconds
        ? gapSeconds
        : MapConfig.maxGpsDistanceGapSeconds;
    final maxPlausible = cappedGapSeconds * MapConfig.maxWalkingSpeedMps;
    final applied = segment < maxPlausible ? segment : maxPlausible;

    _distanceAnchor = point;
    _distanceAnchorAt = fixTime;
    unawaited(tracker.addGpsDelta(applied, mocked: position.isMocked));
  }

  Future<void> _ensureTourismData() async {
    final hasData = await _tourismSpotRepository.hasLocalData();
    if (!hasData) {
      await _runInitialSync();
      return;
    }
    unawaited(_maybeBackgroundResync());
  }

  Future<void> _runInitialSync() async {
    if (!mounted) return;
    setState(() {
      _isInitialSyncing = true;
      _initialSyncError = null;
    });
    try {
      await _tourismSpotRepository.syncBulk();
      if (mounted) await _fetchSpots(_mapController.camera.visibleBounds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialSyncError = '$e');
    } finally {
      if (mounted) setState(() => _isInitialSyncing = false);
    }
  }

  // 스테일(TourismConfig.syncStaleThreshold 초과)일 때만 조용히 재동기화 — 실패해도 유저에게
  // 알리지 않고 기존 캐시로 계속 정상 동작(temp.md 6번, 다음 앱 시작 때 다시 시도됨).
  Future<void> _maybeBackgroundResync() async {
    if (!await _tourismSpotRepository.isStale()) return;
    try {
      await _tourismSpotRepository.syncBulk();
      if (mounted) await _fetchSpots(_mapController.camera.visibleBounds);
    } catch (_) {
      // 무시 — 위 주석 참고
    }
  }

  Future<void> _fetchSpots(LatLngBounds bounds) async {
    try {
      final spots = await _tourismSpotRepository.getSpotsInBounds(bounds);
      if (!mounted) return;
      setState(() {
        _spots = spots;
        _lastQueryCenter = bounds.center;
        _lastQueryRadiusMeters = _distance.as(
          LengthUnit.Meter,
          bounds.center,
          bounds.northEast,
        );
      });
    } catch (_) {
      // 조회 실패 시 이전 마커를 그대로 유지 — 다음 이동/재시도에서 자연 복구
    }
    unawaited(_refreshAcquiredTodaySpotIds());
  }

  // 서비스 지역(서울/인천) 밖 진입을 알리는 스낵바 — GPS 틱마다 반복 노출되지 않도록 밖으로 "막
  // 나갈 때"(outOfServiceArea가 false→true로 바뀔 때) 딱 한 번만 호출됨(위 _positionSub 리스너 참고).
  void _showOutOfServiceAreaMessage() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.outOfServiceAreaMessage),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _refreshAcquiredTodaySpotIds() async {
    final ids = await _eggRepository.getAcquiredTodaySpotIds();
    if (!mounted) return;
    setState(() => _acquiredTodaySpotIds = ids);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && _followMode) {
      setState(() => _followMode = false);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(TourismConfig.refetchDebounce, () {
      final lastCenter = _lastQueryCenter;
      if (lastCenter == null) return;
      final moved = _distance.as(LengthUnit.Meter, lastCenter, camera.center);
      if (moved > _lastQueryRadiusMeters * TourismConfig.refetchDistanceRatio) {
        _fetchSpots(camera.visibleBounds);
      }
    });
  }

  Future<void> _onSpotTapped(TourismSpot spot) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // 시트 내부 콘텐츠는 tourism_spot_sheet.dart가 SketchTheme으로 다시 감싸지만, 시트 자체의
      // Material 배경은 showModalBottomSheet가 이 State의 context(=이 build()가 반환하는 Theme
      // 오버라이드보다 상위 위치, dex_detail_screen.dart의 Theme.of(context) 버그와 같은 이유)의
      // 앙비언트 테마로 만들어서 명시적으로 안 주면 앱 전역 다크 테마의 캔버스 색이 그대로 나옴 —
      // 그래서 여기서 리터럴로 지정.
      backgroundColor: SketchTheme.paper,
      builder: (context) => TourismSpotSheet(spot: spot),
    );
    // 시트에서 알을 새로 획득했을 수 있음 — 뷰포트가 안 움직이면 _fetchSpots 재조회 트리거가 안
    // 걸리므로, 배지가 바로 반영되도록 시트 닫힐 때 별도로 한 번 더 갱신.
    if (mounted) await _refreshAcquiredTodaySpotIds();
  }

  // FAB — 팔로우 토글. 켜져 있으면 끄고(구독은 유지 — 알 획득 반경 원/속도 판정은 계속 동작),
  // 꺼져 있으면: 추적이 이미 살아 있으면 팔로우만 다시 켜고 마지막 위치로 재중심, 아직 추적 전이면
  // _startLocationTracking()으로 동의·권한 게이트부터 태운다. 손으로 지도를 움직이면
  // _onPositionChanged에서 팔로우만 자동으로 꺼짐.
  Future<void> _toggleFollowMode() async {
    if (_followMode) {
      setState(() => _followMode = false);
      return;
    }
    if (_positionSub != null) {
      final last = _currentPositionNotifier.value;
      if (last != null && MapConfig.serviceAreaBounds.contains(last)) {
        // 줌은 현재 값 유지 — 마지막 위치로 카메라만 재중심.
        _mapController.move(last, _mapController.camera.zoom);
      }
      setState(() => _followMode = true);
      return;
    }
    await _startLocationTracking();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 헤더/로고 제거(2026-08-18, 사용자 요청) — 지도가 상태표시줄까지 꽉 차는 몰입형 레이아웃이라,
    // AppBar가 대신 챙겨주던 상단 안전영역을 좌/우 코너 박스가 직접 더해서 상태표시줄과 안 겹치게 함.
    final topInset = MediaQuery.paddingOf(context).top;
    // 최초 동기화 로딩/에러 오버레이(_isInitialSyncing / _initialSyncError)는 지도를 통째로
    // 가리므로, 그동안은 FAB도 숨김 — 지도가 안 보이는데 위치 추적 버튼만 떠 있으면 어색함.
    final coveredByInitialSyncOverlay =
        _isInitialSyncing || _initialSyncError != null;
    // 지도 화면만 그림책+연필 스케치 테마로 지역 오버라이드(2026-08-26, 사용자 요청) — 앱 전역
    // 다크 테마(config/app_theme.dart)는 그대로 두고 이 화면 서브트리에서만 Theme을 갈아끼움.
    return Theme(
      data: SketchTheme.themeData,
      child: Scaffold(
        floatingActionButton: coveredByInitialSyncOverlay
            ? null
            : SketchFab(
                onPressed: _toggleFollowMode,
                tooltip: _followMode
                    ? l10n.stopFollowingLocationTooltip
                    : l10n.moveToCurrentLocationTooltip,
                active: _followMode,
                icon: _followMode
                    ? Icons.my_location
                    : Icons.location_searching,
              ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: MapConfig.initialCenter,
                // 앱 시작 시 초기 줌 — 주변 마커가 바로 잘 보이는 확대 수준으로 시작(예전엔 zoom
                // 13 고정값이라 넓은 지도가 잠깐 보였음). FAB "현재 위치로 이동"은 줌을 바꾸지
                // 않으므로(2026-08-30), 이후 팔로우가 켜져도 이 줌이 유지된다.
                initialZoom: MapConfig.initialZoom,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                // 카메라(뷰포트 전체)를 서비스 지역 밖으로 못 나가게 묶음 — 이 범위 밖은 타일이
                // 없어 회색 화면만 보이므로, 팬/줌으로도 회색이 아예 안 보이게 하드 클램프.
                // contain은 "뷰포트가 bounds 안에 완전히 들어갈 때"만 제대로 동작하므로
                // minZoom(z13)에서 서울+인천 BBOX가 화면을 덮는지 에뮬레이터로 확인 필요 —
                // 세로로 넘치면 minZoom을 한 단계 올려야 함(계산보다 실측, study_folder/2-3 참고).
                cameraConstraint: CameraConstraint.contain(
                  bounds: MapConfig.serviceAreaBounds,
                ),
                onMapReady: () =>
                    _fetchSpots(_mapController.camera.visibleBounds),
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrlTemplate,
                  userAgentPackageName: 'com.tourmon.app',
                  maxNativeZoom: MapConfig.maxNativeZoom.toInt(),
                  tileProvider: _tileProvider,
                  // 팬/줌 도중 매 프레임 타일을 요청하는 기본 동작을 이동 중 일정 간격당 1회로
                  // 제한(멈추면 trailing 갱신으로 최종 화면 보정, MapConfig.tileUpdateThrottle 주석 참고).
                  tileUpdateTransformer: TileUpdateTransformers.throttle(
                    MapConfig.tileUpdateThrottle,
                  ),
                ),
                // 알 획득 판정 반경 — 모든 사용자에게 상시 표시(2026-08-26, 사용자 요청. 이전엔
                // 디버그 모드 전용이었음). 실제 판정 기준은 항상 서버(game-config.ts)이고 이 원은
                // 시각화일 뿐. 마커 레이어보다 먼저(=뒤에) 그려야 마커 탭이 이 원에 가로막히지 않음
                // (실기기 확인 — 반경 원이 마커보다 앞에 있으면 겹치는 마커를 탭할 수 없었음,
                // Document/temp.md 참고).
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _currentPositionNotifier,
                  builder: (context, position, _) => position == null
                      ? const SizedBox.shrink()
                      : CircleLayer(
                          circles: [
                            CircleMarker(
                              point: position,
                              radius: MapConfig.eggAcquisitionRadiusMeters,
                              useRadiusInMeter: true,
                              color: SketchTheme.accentYellow.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 60,
                    // 패키지 기본값(20)이 MapConfig.maxZoom(18)보다 커서 최대 줌에서도 클러스터링이
                    // 안 풀림 — 대표 좌표끼리 5~50m만 떨어져 있어도(대표 선정 기준은 study_folder/
                    // 2-2 문서 참고) 최대 줌에서 뭉쳐 보이는 문제가 있어 명시적으로 지정.
                    // 라이브러리 조건이 "zoom > disableClusteringAtZoom"이라 maxZoom 그대로 넣으면
                    // 최대 줌에서도 안 풀려서 -1.
                    disableClusteringAtZoom: MapConfig.maxZoom.toInt() - 1,
                    // 기본값(false)이면 지도 회전에 마커도 같이 돌아감 — 핀/클러스터 숫자는 항상 화면
                    // 기준으로 똑바로 서 있는 게 자연스러워서 카운터 로테이션 켬.
                    rotate: true,
                    size: const Size(36, 36),
                    markers: [
                      for (final spot in _spots)
                        if (_categoryMarkerAssets[spot.contentTypeId]
                            case final asset?)
                          Marker(
                            point: spot.position,
                            width: 36,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => _onSpotTapped(spot),
                              child: _MarkerWithCooldownBadge(
                                acquiredToday: _acquiredTodaySpotIds.contains(
                                  spot.id,
                                ),
                                child: Image.asset(
                                  asset,
                                  width: 36,
                                  height: 44,
                                ),
                              ),
                            ),
                          )
                        else
                          Marker(
                            point: spot.position,
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _onSpotTapped(spot),
                              child: _MarkerWithCooldownBadge(
                                acquiredToday: _acquiredTodaySpotIds.contains(
                                  spot.id,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.redAccent,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                    ],
                    builder: (context, clusteredMarkers) => CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Text(
                        '${clusteredMarkers.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                // 위치 추적이 시작된 뒤에만(_subscribeToPositionStream) 파란 점 레이어를 얹음 —
                // 그 전에는 _markerPositionStream이 null.
                if (_markerPositionStream != null)
                  CurrentLocationLayer(
                    positionStream: _markerPositionStream!,
                    alignPositionOnUpdate: _alignPositionOnUpdate,
                    // 패키지 기본 정확도 원(반투명 파랑)을 끔 — 우리가 그리는 알 획득 반경 원
                    // (위 ValueListenableBuilder)과 겹쳐 보이는 데다, 그 CircleLayer는 원 안쪽
                    // 탭을 흡수해서 마커 위에 겹치면 마커를 못 누르게 됨. 파란 점/방향 콘은 유지.
                    style: const LocationMarkerStyle(showAccuracyCircle: false),
                  ),
              ],
            ),
            Positioned(
              top: topInset + 8,
              left: 8,
              // 배너에서 "위치 권한 켜기"를 누르면 이 화면의 기존 위치 플로우를 그대로 태운다
              // (동의 다이얼로그 → OS 요청 → deniedForever 설정 안내 → 스트림 구독까지, 6-b).
              child: PartnerEggProgressBox(
                onRequestLocationSetup: _startLocationTracking,
              ),
            ),
            Positioned(
              top: topInset + 8,
              right: 8,
              child: const QuickActionsBox(),
            ),
            if (DebugConfig.isEnabled)
              Positioned(
                bottom: 8,
                left: 8,
                child: StreamBuilder<MapEvent>(
                  stream: _mapController.mapEventStream,
                  builder: (context, snapshot) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.black54,
                      child: Text(
                        'zoom: ${_mapController.camera.zoom.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (DebugConfig.isEnabled)
              Positioned(
                left: 8,
                bottom: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'debug_db_viewer',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DebugDbViewerScreen(),
                        ),
                      ),
                      tooltip: '[디버그] 로컬 DB 보기',
                      child: const Icon(Icons.storage),
                    ),
                    const SizedBox(height: 8),
                    const DebugDistanceInjectorButton(),
                    const SizedBox(height: 8),
                    const DebugActivityPermissionButton(),
                    const SizedBox(height: 8),
                    const DebugAddEggButton(),
                  ],
                ),
              ),
            // 팔로우 중 속도 초과로 카메라 재중심만 일시정지된 상태 — 파란 점은 계속 움직이는데
            // 지도만 안 따라오면 "고장났나" 오해하기 쉬워서, 상태가 유지되는 내내 보이는 작은 배지로
            // 안내(스낵바처럼 한 번 뜨고 사라지면 차량 이동이 길 때 놓치기 쉬움, temp.md 참고).
            if (_followMode && _isSpeeding)
              Positioned(
                right: 16,
                bottom: 88,
                child: SketchCard(
                  rotationDegrees: -2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  seed: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, size: 16),
                      const SizedBox(width: 6),
                      Text(l10n.mapFollowPausedSpeedMessage),
                    ],
                  ),
                ),
              ),
            if (coveredByInitialSyncOverlay)
              Positioned.fill(
                child: ColoredBox(
                  color: SketchTheme.paper,
                  child: Center(
                    child: _initialSyncError != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.tourismDataSyncFailedMessage),
                              const SizedBox(height: 12),
                              SketchButton(
                                onPressed: _runInitialSync,
                                label: l10n.retryButton,
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: SketchTheme.accent,
                              ),
                              const SizedBox(height: 12),
                              Text(l10n.tourismDataSyncingMessage),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 오늘 이미 획득한 스팟 마커에 얹는 작은 체크 배지(Document/temp.md "마커 쿨타임 배지") — 마커
/// 자체(회색조 처리 등)는 안 바꾸고 배지만 얹는 쪽으로 결정.
class _MarkerWithCooldownBadge extends StatelessWidget {
  final bool acquiredToday;
  final Widget child;

  const _MarkerWithCooldownBadge({
    required this.acquiredToday,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!acquiredToday) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
