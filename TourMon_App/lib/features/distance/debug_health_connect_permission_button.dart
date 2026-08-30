import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import 'distance_tracker_service.dart';

/// 디버그 전용(`--dart-define=DEBUG_MODE=true`) — 파트너 알 없이도 Health Connect 권한 재요청
/// 플로우(`DistanceTrackerService.start(requestPermissionIfNeeded: true)`)를 직접 트리거하는 버튼.
/// 원래 이 요청은 파트너 알을 처음 지정하는 시점에만 뜨는데(egg_inventory_screen.dart
/// `_onPartnerToggled`), 아직 알을 하나도 획득 못 한 상태(스팟 근처가 아니거나 쿨타임 등)에서도
/// Health Connect 권한 요청/설치 유도 흐름을 바로 테스트하고 싶을 때 씀.
class DebugHealthConnectPermissionButton extends StatelessWidget {
  const DebugHealthConnectPermissionButton({super.key});

  Future<void> _requestPermission(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final authSession = context.read<AuthSession>();
    try {
      await DistanceTrackerService.instance.start(authSession, requestPermissionIfNeeded: true);
      messenger.showSnackBar(
        const SnackBar(content: Text('[디버그] Health Connect 권한 요청 완료 — 로그/Health Connect 앱에서 결과 확인')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('[디버그] 권한 요청 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_health_connect_permission',
      onPressed: () => _requestPermission(context),
      tooltip: '[디버그] Health Connect 권한 재요청(파트너 알 없이 테스트)',
      child: const Icon(Icons.health_and_safety),
    );
  }
}
