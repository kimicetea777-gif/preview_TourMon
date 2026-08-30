import 'package:flutter/material.dart';

import 'force_update_screen.dart';
import 'notice_banner.dart';
import 'remote_config_service.dart';

/// `MaterialApp.home`을 감싸서 원격 설정을 반영하는 얇은 래퍼:
/// - 설치 빌드가 최소 지원 빌드 미만이면 [child] 대신 [ForceUpdateScreen]
/// - 활성 공지가 있으면 [child] 위에 [NoticeBanner] 한 줄
///
/// 공지가 없을 땐 [child]를 그대로 전체화면으로 둬서 기존 동작과 완전히 동일. 공지가 떴다
/// 사라져도 body 쪽 요소에 `ValueKey`를 박아둬서 [child](=`MapScreen`)의 State가 유지됨
/// (지도 위치/로드된 마커가 리셋되지 않게).
class AppGate extends StatelessWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RemoteConfigService.instance,
      builder: (context, _) {
        final service = RemoteConfigService.instance;
        if (service.updateRequired) {
          return const ForceUpdateScreen();
        }
        final notice = service.activeVisibleNotice;
        return Column(
          children: [
            if (notice != null)
              SafeArea(
                key: const ValueKey('app-gate-notice'),
                bottom: false,
                child: NoticeBanner(
                  notice: notice,
                  onDismiss: () => service.dismiss(notice.id),
                ),
              ),
            Expanded(key: const ValueKey('app-gate-body'), child: child),
          ],
        );
      },
    );
  }
}
