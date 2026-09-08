import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../l10n/app_localizations.dart';

/// 거리 수치가 실시간이 아니라 [GameConfig.distanceServerSyncInterval] 주기로만 갱신된다는 것과
/// 그 이유(배터리 절약), 그리고 즉시 갱신하는 방법(새로고침 버튼 / 아래로 당기기)을 알려주는
/// 바텀시트. 지도 화면 파트너 알 박스와 알 보관함 화면 양쪽에서 같은 내용을 재사용.
///
/// 주기(분)는 [GameConfig]에서 읽어와 문구에 채움 — "튜닝 값 하드코딩 금지" 원칙에 따라 이
/// 안내 문구도 설정값을 단일 소스로 삼음.
Future<void> showDistanceRefreshInfoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 이 시트는 알 보관함/지도 화면의 지역 SketchTheme 서브트리 바깥(Overlay)이라 앱 전역 다크
    // 테마의 강조색(주황)이 배어 나옴 — 순수 정보 안내에 경고색은 어울리지 않아 크림색 배경 +
    // 잉크색 아이콘/본문으로 고정(egg_inventory_screen.dart의 _GuestShelfLifeBanner와 같은 처리).
    backgroundColor: SketchTheme.paperLight,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final minutes = GameConfig.distanceServerSyncInterval.inMinutes;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.battery_saver,
                    size: 20,
                    color: SketchTheme.ink.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.distanceRefreshInfoTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SketchTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.distanceRefreshInfoBody(minutes),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SketchTheme.ink.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// [lastSyncedAt]를 "방금 갱신됨 / N분 전 갱신 / N시간 전 갱신 / 아직 갱신 안 됨" 상대 시각
/// 문구로 변환. 거리 박스/화면이 폴링으로 주기적으로 다시 그릴 때마다 자연스럽게 최신화됨.
String distanceRefreshedAgoLabel(AppLocalizations l10n, DateTime? lastSyncedAt) {
  if (lastSyncedAt == null) return l10n.distanceRefreshNeverSynced;
  final diff = DateTime.now().difference(lastSyncedAt);
  if (diff.inMinutes < 1) return l10n.distanceRefreshedJustNow;
  if (diff.inMinutes < 60) return l10n.distanceRefreshedMinutesAgo(diff.inMinutes);
  return l10n.distanceRefreshedHoursAgo(diff.inHours);
}
