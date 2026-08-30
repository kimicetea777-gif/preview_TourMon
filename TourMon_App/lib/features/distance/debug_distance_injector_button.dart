import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../config/game_config.dart';

/// 디버그 전용(`--dart-define=DEBUG_MODE=true`) — Health Connect에 테스트용 걸음수를 직접 써넣는
/// 버튼. Health Connect 걸음수는 GPS 모킹(`adb emu geo fix`)이나 sqlite 직접 patch로는 만들 수 없고,
/// Health Connect 앱 UI에서 수동으로 값을 넣으면 `recordingMethod=manual`로 기록돼
/// `DistanceTrackerService`가 일부러 걸러내므로(치팅 방지, Document/temp.md 참고) 에뮬레이터에서
/// 전체 플로우(권한 요청→동기화→파트너알 진행→부화)를 검증하려면 `recordingMethod=automatic`으로
/// 직접 써넣는 이 경로가 필요함. `WRITE_STEPS` 권한은 debug 매니페스트
/// (`android/app/src/debug/AndroidManifest.xml`)에만 있어 release 빌드엔 안 들어감 — 이 버튼도
/// `DebugConfig.isEnabled`일 때만 화면에 노출되므로 이중으로 안전.
///
/// `DistanceTrackerService`가 STEPS를 조회해 `GameConfig.stepsToMetersFactor`로 환산하는 쪽으로
/// 바뀌어서(2026-08-26), 이 버튼도 거리 대신 걸음수를 주입 — `_injectMeters`는 검증용 목표
/// 거리일 뿐, 실제로 쓰는 값은 그걸 역산한 걸음수.
class DebugDistanceInjectorButton extends StatelessWidget {
  const DebugDistanceInjectorButton({super.key});

  static const _injectMeters = 500.0;

  Future<void> _inject(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final health = Health();
    health.configure();
    try {
      final granted = await health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.WRITE],
      );
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('[디버그] Health Connect WRITE 권한이 거부됨')),
        );
        return;
      }
      final steps = (_injectMeters / GameConfig.stepsToMetersFactor).round();
      final now = DateTime.now();
      final ok = await health.writeHealthData(
        value: steps.toDouble(),
        unit: HealthDataUnit.COUNT,
        type: HealthDataType.STEPS,
        startTime: now.subtract(const Duration(minutes: 1)),
        endTime: now,
        recordingMethod: RecordingMethod.automatic,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '[디버그] 걸음수 $steps걸음(약 ${_injectMeters.toInt()}m) 주입 완료'
                : '[디버그] 걸음수 주입 실패',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('[디버그] 걸음수 주입 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_distance_injector',
      onPressed: () => _inject(context),
      tooltip: '[디버그] Health Connect에 약 ${_injectMeters.toInt()}m 분량 걸음수 주입',
      child: const Icon(Icons.bug_report),
    );
  }
}
