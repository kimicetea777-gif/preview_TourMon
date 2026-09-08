import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import 'distance_tracker_service.dart';

/// 디버그 전용(`--dart-define=DEBUG_MODE=true`) — "앱이 꺼져 있어도 거리 측정" 토글
/// (`DistanceTrackerService.enableBackgroundDistance`, `ACTIVITY_RECOGNITION` 요청 + pedometer
/// 보조 경로 시작)을 알 보관함에 안 들어가고 바로 트리거하는 버튼. 아직 알을 하나도 못 받은
/// 상태에서 권한 요청 흐름을 테스트할 때 쓴다.
class DebugActivityPermissionButton extends StatelessWidget {
  const DebugActivityPermissionButton({super.key});

  Future<void> _requestPermission(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final authSession = context.read<AuthSession>();
    try {
      final ok = await DistanceTrackerService.instance.enableBackgroundDistance(
        authSession,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '[디버그] ACTIVITY_RECOGNITION 허용됨 — 보조 경로 활성'
                : '[디버그] ACTIVITY_RECOGNITION 거부됨(GPS 주 경로는 정상)',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('[디버그] 권한 요청 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_activity_permission',
      onPressed: () => _requestPermission(context),
      tooltip: '[디버그] 걸음 기록 권한 재요청(파트너 알 없이 테스트)',
      child: const Icon(Icons.directions_walk),
    );
  }
}
