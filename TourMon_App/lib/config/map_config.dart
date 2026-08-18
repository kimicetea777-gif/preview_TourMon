import 'package:latlong2/latlong.dart';

/// 1단계 배경 지도 설정값 — 하드코딩 금지 원칙에 따라 이 파일 한 곳에 모음.
/// 데이터 파이프라인/결정 배경: TourMon/scripts/map-pipeline, Document/temp_2.md
class MapConfig {
  MapConfig._();

  /// 타일 서버 베이스 URL. 코드에 하드코딩하지 않고 실행 시점에 주입받음:
  ///   프로덕션(권장): --dart-define=TILE_SERVER_BASE_URL=https://tiles.kimicetea.app
  ///     (Cloudflare Worker가 R2의 PMTiles 파일을 직접 서빙 — mini-PC 경유 없음, 결정 배경: Document/temp_3.md)
  ///   로컬 pmtiles-server로 테스트할 때만:
  ///     Android 에뮬레이터: --dart-define=TILE_SERVER_BASE_URL=http://10.0.2.2:8080
  ///     iOS 시뮬레이터:     --dart-define=TILE_SERVER_BASE_URL=http://localhost:8080
  ///     실기기(같은 LAN):   --dart-define=TILE_SERVER_BASE_URL=http://<개발 PC LAN IP>:8080
  static const String tileServerBaseUrl = String.fromEnvironment(
    'TILE_SERVER_BASE_URL',
  );

  /// 타일 서버(Worker 또는 로컬 pmtiles-server)가 서빙하는 아카이브 이름
  /// (TourMon/scripts/map-pipeline/config.ts의 PMTILES_SERVE_ARCHIVE_NAME과 동일해야 함)
  static const String archiveName = 'seoul-incheon-raster';

  static String get tileUrlTemplate {
    if (tileServerBaseUrl.isEmpty) {
      throw StateError(
        'TILE_SERVER_BASE_URL이 주입되지 않음 — flutter run 실행 시 '
        '--dart-define=TILE_SERVER_BASE_URL=http://... 를 반드시 지정할 것',
      );
    }
    return '$tileServerBaseUrl/$archiveName/{z}/{x}/{y}.png';
  }

  /// 렌더링된 실제 최대 줌 레벨 (map-pipeline config.ts의 MAX_ZOOM과 동일).
  /// 이보다 깊은 줌은 flutter_map이 이 레벨 타일을 업스케일(오버줌)해서 보여줌.
  static const double maxNativeZoom = 16;

  /// z16(maxNativeZoom)보다 깊은 줌은 z16 타일을 업스케일한 화면 — 실측(2026-08-17)으로
  /// z19까지 두면 흐림이 심해서 z18로 상한. 진짜 고해상도가 필요해지면 render 파이프라인을
  /// z17+ 대상으로 재실행해서 maxNativeZoom 자체를 올리는 게 근본 해결책(README.md 참고).
  static const double maxZoom = 18;

  /// 최대 축소 줌 — 에뮬레이터 실측(2026-08-17)으로 z13 확정.
  /// 이보다 축소하면 서비스 범위 밖 빈 배경이 보이고, 마커 API 뷰포트 쿼리
  /// 결과도 커지는 문제가 있음(Document/temp.md 참고, 계산상 예상값은 z9였음)
  static const double minZoom = 13;

  /// 초기 지도 중심 — 서울시청 부근
  static const LatLng initialCenter = LatLng(37.5665, 126.9780);
  static const double initialZoom = 13;

  /// FMTC(flutter_map_tile_caching) 로컬 캐시 스토어 이름
  static const String tileCacheStoreName = 'seoul_incheon';

  /// FAB로 "현재 위치로 이동"(팔로우 모드 켜기) 실행 시 맞추는 줌 레벨 — 도착 직후 바로 주변
  /// 마커가 잘 보이는 확대 수준(잠정값, initialZoom(13)보다 훨씬 가깝게).
  static const double followModeZoom = 17;

  /// 카메라 팔로우 모드 중 이 속도(m/s)를 넘으면 카메라 재중심을 일시정지(파란 점은 계속 움직임) —
  /// 차량 이동 중 GPS 업데이트마다 카메라가 튀며 타일/마커를 급하게 재조회하는 걸 막기 위함
  /// (Document/temp.md 참고). 도보(~1.4m/s)보다 넉넉하게 잡아 러닝까지는 허용 — 실측/조정 전 잠정값.
  static const double maxWalkingSpeedMps = 4.0;
}
