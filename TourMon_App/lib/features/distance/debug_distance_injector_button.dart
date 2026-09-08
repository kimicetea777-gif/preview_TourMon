import 'package:flutter/material.dart';

import 'distance_tracker_service.dart';

/// 디버그 전용(`--dart-define=DEBUG_MODE=true`) — 실제로 걷지 않고 거리 적립 전체 경로
/// (일별 히스토리 → 파트너 알 진행 → 서버 pending/flush)를 검증하기 위한 버튼. 거리 측정
/// 이중화(Document/temp.md) 이후 GPS 좌표 모킹(`adb emu geo fix`)만으로도 주 경로 검증은
/// 가능하지만, "정해진 양을 한 번에 밀어넣어" 부화 도달까지 빠르게 확인하려면 이 경로가 편리함.
class DebugDistanceInjectorButton extends StatelessWidget {
  const DebugDistanceInjectorButton({super.key});

  static const _injectMeters = 500.0;

  Future<void> _inject(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DistanceTrackerService.instance.debugCreditMeters(_injectMeters);
      messenger.showSnackBar(
        SnackBar(
          content: Text('[디버그] 거리 ${_injectMeters.toInt()}m 적립 완료'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('[디버그] 거리 적립 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_distance_injector',
      onPressed: () => _inject(context),
      tooltip: '[디버그] 거리 ${_injectMeters.toInt()}m 적립',
      child: const Icon(Icons.bug_report),
    );
  }
}
