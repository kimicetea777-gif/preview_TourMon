import 'package:package_info_plus/package_info_plus.dart';

/// 설치된 앱의 빌드 번호(Android versionCode = pubspec `version: x.y.z+BUILD`의 `+BUILD`)를
/// 런타임에 한 번 읽어두는 홀더. 원격 설정(`RemoteConfigService`)의 최소 지원 빌드 게이트가
/// 이 값과 비교함. [main]에서 `runApp` 전에 [init]을 await할 것.
class AppInfo {
  AppInfo._();

  /// 읽기 실패 시 0으로 남음 — `RemoteConfigService`는 0을 "알 수 없음"으로 취급해 게이트를
  /// 걸지 않음(fail-open: CDN/플러그인 문제로 사용자를 잠그지 않기 위함).
  static int buildNumber = 0;

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      buildNumber = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      buildNumber = 0;
    }
  }
}
