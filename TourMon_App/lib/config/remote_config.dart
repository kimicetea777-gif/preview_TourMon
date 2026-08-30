/// 원격 설정(공지 + 최소 지원 빌드 게이트)을 담은 JSON의 위치.
///
/// 이 JSON은 TourMon Next.js API가 아니라 **tourmon-asset-cdn 워커**(`assets.kimicetea.app`,
/// R2 앞단)가 서빙함 — 백엔드(mini-PC)가 죽어도 "서버 점검 중" 같은 공지가 떠야 하므로 서버와
/// 완전히 독립된 경로에 둔다(Document/worker_manual.md 참고). 도메인은 고정 인프라라 기본값을
/// 두되 `--dart-define=ASSET_CDN_BASE_URL=...`로 덮어쓸 수 있음(seed.ts의 `ASSET_CDN_BASE_URL`
/// 상수와 같은 값).
class RemoteConfig {
  RemoteConfig._();

  static const String assetCdnBaseUrl = String.fromEnvironment(
    'ASSET_CDN_BASE_URL',
    defaultValue: 'https://assets.kimicetea.app',
  );

  static Uri get appNoticeUrl =>
      Uri.parse('$assetCdnBaseUrl/config/app-notice.json');

  /// 원격 설정을 아직 못 받았을 때 강제 업데이트 화면이 쓸 스토어 URL 폴백.
  static const String fallbackStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tourmon.mobile';

  /// 네트워크 조회 타임아웃 — 부팅 경로에서 fire-and-forget로 호출되지만 무한정 매달리지 않게.
  static const Duration fetchTimeout = Duration(seconds: 8);
}
