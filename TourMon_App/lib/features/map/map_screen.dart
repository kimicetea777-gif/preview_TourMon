import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/debug_config.dart';
import '../../config/map_config.dart';
import '../../config/tourism_config.dart';
import '../../data/tourism_spot_repository.dart';
import '../../l10n/app_localizations.dart';
import '../egg/egg_repository.dart';
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
  bool _followMode = false;
  bool _isSpeeding = false;

  // GPS 스트림을 CurrentLocationLayer와 우리 쪽(속도 판정 + 디버그 원 표시)이 하나만 공유 —
  // defaultPositionStreamSource()는 CurrentLocationLayer가 positionStream 없이 쓸 때 내부적으로
  // 쓰는 것과 동일한 소스(권한 요청/거부 플로우 포함, broadcast)라 이걸 그대로 주입하면 패키지 기본
  // 동작을 잃지 않으면서 구독을 하나로 합칠 수 있음.
  late final Stream<Position?> _positionStream;
  late final Stream<LocationMarkerPosition?> _markerPositionStream;
  StreamSubscription<Position?>? _positionSub;
  LatLng? _debugPosition;

  AlignOnUpdate get _alignPositionOnUpdate =>
      _followMode && !_isSpeeding ? AlignOnUpdate.always : AlignOnUpdate.never;

  @override
  void initState() {
    super.initState();
    _positionStream = const LocationMarkerDataStreamFactory().defaultPositionStreamSource();
    _markerPositionStream = const LocationMarkerDataStreamFactory()
        .fromGeolocatorPositionStream(stream: _positionStream);
    _positionSub = _positionStream.listen((position) {
      if (!mounted || position == null) return;
      // 실제로 바뀔 때만 setState — 매 GPS 틱마다 부르면 프로덕션 빌드에도 지도 화면 전체가
      // 상시 리빌드됨(temp.md 재검토 항목 참고).
      final speeding = position.speed > MapConfig.maxWalkingSpeedMps;
      if (speeding != _isSpeeding) {
        setState(() => _isSpeeding = speeding);
      }
      if (DebugConfig.isEnabled) {
        setState(() => _debugPosition = LatLng(position.latitude, position.longitude));
      }
    });
    _ensureTourismData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
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
      builder: (context) => TourismSpotSheet(spot: spot),
    );
    // 시트에서 알을 새로 획득했을 수 있음 — 뷰포트가 안 움직이면 _fetchSpots 재조회 트리거가 안
    // 걸리므로, 배지가 바로 반영되도록 시트 닫힐 때 별도로 한 번 더 갱신.
    if (mounted) await _refreshAcquiredTodaySpotIds();
  }

  // FAB — 꺼져있으면 켜면서 즉시 1회 이동, 켜져있으면 그냥 끔(Google/Naver Maps와 동일한 팔로우
  // 토글 패턴, temp.md 참고). 손으로 지도를 움직이면 _onPositionChanged에서 자동으로 꺼짐.
  Future<void> _toggleFollowMode() async {
    if (_followMode) {
      setState(() => _followMode = false);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.locationServiceDisabledMessage)));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.locationPermissionDeniedMessage)));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        MapConfig.followModeZoom,
      );
      setState(() => _followMode = true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.genericErrorMessage(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 헤더/로고 제거(2026-08-18, 사용자 요청) — 지도가 상태표시줄까지 꽉 차는 몰입형 레이아웃이라,
    // AppBar가 대신 챙겨주던 상단 안전영역을 좌/우 코너 박스가 직접 더해서 상태표시줄과 안 겹치게 함.
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleFollowMode,
        tooltip: _followMode
            ? l10n.stopFollowingLocationTooltip
            : l10n.moveToCurrentLocationTooltip,
        backgroundColor: _followMode ? const Color(0xFF0A0F1E) : Colors.grey.shade300,
        foregroundColor: _followMode ? Colors.white : Colors.grey.shade700,
        child: Icon(_followMode ? Icons.my_location : Icons.location_searching),
      ),
      body: Stack(
        children: [
          FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: MapConfig.initialCenter,
          initialZoom: MapConfig.initialZoom,
          minZoom: MapConfig.minZoom,
          maxZoom: MapConfig.maxZoom,
          onMapReady: () => _fetchSpots(_mapController.camera.visibleBounds),
          onPositionChanged: _onPositionChanged,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrlTemplate,
            userAgentPackageName: 'com.tourmon.app',
            maxNativeZoom: MapConfig.maxNativeZoom.toInt(),
            tileProvider: _tileProvider,
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
                  if (_categoryMarkerAssets[spot.contentTypeId] case final asset?)
                    Marker(
                      point: spot.position,
                      width: 36,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _onSpotTapped(spot),
                        child: _MarkerWithCooldownBadge(
                          acquiredToday: _acquiredTodaySpotIds.contains(spot.id),
                          child: Image.asset(asset, width: 36, height: 44),
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
                          acquiredToday: _acquiredTodaySpotIds.contains(spot.id),
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
          // 알 획득 판정 반경(디버그 모드 전용) — 실제 판정 기준은 항상 서버(game-config.ts)이고
          // 이 원은 시각화일 뿐. CurrentLocationLayer보다 먼저 그려서 파란 점이 위에 오게 함.
          if (DebugConfig.isEnabled && _debugPosition != null)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _debugPosition!,
                  radius: DebugConfig.eggAcquisitionRadiusMeters,
                  useRadiusInMeter: true,
                  color: Colors.yellow.withValues(alpha: 0.35),
                  borderColor: Colors.orange,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          CurrentLocationLayer(
            positionStream: _markerPositionStream,
            alignPositionOnUpdate: _alignPositionOnUpdate,
          ),
        ],
          ),
          Positioned(
            top: topInset + 8,
            left: 8,
            child: const PartnerEggProgressBox(),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black54,
                    child: Text(
                      'zoom: ${_mapController.camera.zoom.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          // 팔로우 중 속도 초과로 카메라 재중심만 일시정지된 상태 — 파란 점은 계속 움직이는데
          // 지도만 안 따라오면 "고장났나" 오해하기 쉬워서, 상태가 유지되는 내내 보이는 작은 배지로
          // 안내(스낵바처럼 한 번 뜨고 사라지면 차량 이동이 길 때 놓치기 쉬움, temp.md 참고).
          if (_followMode && _isSpeeding)
            Positioned(
              right: 16,
              bottom: 88,
              child: Chip(
                avatar: const Icon(Icons.speed, size: 16),
                label: Text(l10n.mapFollowPausedSpeedMessage),
              ),
            ),
          if (_isInitialSyncing || _initialSyncError != null)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: _initialSyncError != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.tourismDataSyncFailedMessage),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _runInitialSync,
                              child: Text(l10n.retryButton),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(l10n.tourismDataSyncingMessage),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 오늘 이미 획득한 스팟 마커에 얹는 작은 체크 배지(Document/temp.md "마커 쿨타임 배지") — 마커
/// 자체(회색조 처리 등)는 안 바꾸고 배지만 얹는 쪽으로 결정.
class _MarkerWithCooldownBadge extends StatelessWidget {
  final bool acquiredToday;
  final Widget child;

  const _MarkerWithCooldownBadge({required this.acquiredToday, required this.child});

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
