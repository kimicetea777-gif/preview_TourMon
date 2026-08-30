import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../consent/location_consent_dialog.dart';

/// 위치 기반 동작(지도 FAB 팔로우 시작, 마커에서 알 획득)이 공통으로 거치는 게이트 —
/// ① 인앱 위치정보 동의 → ② OS 위치 서비스 ON → ③ OS 위치 권한(denied면 요청)을 순서대로 확인.
///
/// 알 획득은 "관광지에 실제로 가 있어야 한다"가 규칙이라 위치가 본질인 동작이므로, FAB를 안 누르고
/// 곧장 알 획득을 눌러도 여기서 OS 권한을 요청한다(앱 실행 시점엔 요청 안 한다는 FAB의 JIT 원칙과
/// 상충하지 않음 — 사용자가 명시적으로 누른 위치 기반 액션이라 그 시점이 곧 JIT).
///
/// 결과 표시(스낵바 / 시트 인라인 텍스트)는 호출부마다 방식이 달라서 이 함수가 직접 안 띄운다
/// (인앱 동의 다이얼로그만 예외). [locationGateMessage]로 결과에 맞는 문구를 얻어 호출부가 띄운다.
enum LocationGateResult {
  /// 세 단계 모두 통과 — 위치 조회 진행 가능.
  granted,

  /// 사용자가 인앱 동의 다이얼로그를 스스로 취소 — 별도 안내 불필요.
  consentDeclined,

  /// OS 위치 서비스(GPS) 자체가 꺼져 있음.
  serviceDisabled,

  /// 위치 권한 거부 — 다음에 다시 요청 가능.
  permissionDenied,

  /// 위치 권한 영구 거부 — 앱이 다시 요청할 수 없어 기기 설정에서 직접 켜야 함.
  permissionDeniedForever,
}

Future<LocationGateResult> ensureLocationReady(BuildContext context) async {
  if (!await ensureLocationConsent(context)) {
    return LocationGateResult.consentDeclined;
  }
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationGateResult.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationGateResult.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationGateResult.permissionDeniedForever;
    }
    return LocationGateResult.granted;
  } catch (e) {
    // 매니페스트 권한 정의 누락 등 흔치 않은 런타임 오류 — "권한 없음"과 같은 안내로 수렴시킨다
    // (호출부가 어차피 위치 조회를 진행하면 안 되는 상태라는 점은 동일).
    developer.log('위치 권한 게이트 확인 실패: $e', name: 'ensureLocationReady');
    return LocationGateResult.permissionDenied;
  }
}

/// [ensureLocationReady] 결과에 대응하는 사용자 안내 문구. [LocationGateResult.granted]와
/// [LocationGateResult.consentDeclined](사용자가 스스로 취소)는 안내가 필요 없어 null.
String? locationGateMessage(AppLocalizations l10n, LocationGateResult result) {
  switch (result) {
    case LocationGateResult.granted:
    case LocationGateResult.consentDeclined:
      return null;
    case LocationGateResult.serviceDisabled:
      return l10n.locationServiceDisabledMessage;
    case LocationGateResult.permissionDenied:
      return l10n.locationPermissionDeniedMessage;
    case LocationGateResult.permissionDeniedForever:
      return l10n.locationPermissionDeniedForeverMessage;
  }
}
