import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/sketch/sketch_card.dart';
import '../../data/daily_distance_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../auth/auth_session.dart';
import '../distance/distance_refresh_info_sheet.dart';
import '../distance/distance_tracker_service.dart';
import '../distance/health_connect_notice_dialog.dart';
import '../egg/distance_format.dart';
import '../egg/egg_image.dart';
import '../egg/egg_repository.dart';
import '../egg/user_egg.dart';

/// 지도 화면 좌상단 파트너 알 진행도 박스(Document/temp.md 참고) — 순수 읽기 전용 요약. 알/빈
/// 슬롯 행을 포함해 박스 어디를 탭해도 접기/펼치기만 토글될 뿐 다른 화면으로 이동하지 않음
/// (2026-08-18, 사용자 요청으로 행 탭 시 `EggInventoryScreen` 이동을 제거 — 알 보관함 진입점은
/// 이제 `QuickActionsBox` 하나로 통일).
class PartnerEggProgressBox extends StatefulWidget {
  const PartnerEggProgressBox({super.key});

  @override
  State<PartnerEggProgressBox> createState() => _PartnerEggProgressBoxState();
}

class _PartnerEggProgressBoxState extends State<PartnerEggProgressBox> {
  final _eggRepository = const EggRepository();
  final _dailyDistanceRepository = const DailyDistanceRepository();

  bool _expanded = true;
  bool _syncing = false;
  List<UserEgg> _partnerEggs = [];
  double _todayDistanceMeters = 0;
  DateTime? _lastSyncedAt;
  Timer? _refreshTimer;
  // 파트너 알이 있는데 Health Connect 권한이 없어 거리가 안 잡히는 상태 — 이때만 인라인 배너를
  // 띄운다("걸었는데 수치가 안 올라간다"는 사용자 혼란 대응). 권한 요청 팝업은 파트너 알을
  // 처음 지정할 때(egg_inventory_screen.dart)가 정식 시점이고, 이 배너는 그걸 놓쳤거나 설정에서
  // 회수한 사용자의 복구 경로.
  bool _needsHcConnect = false;

  @override
  void initState() {
    super.initState();
    _load();
    // egg_inventory_screen.dart와 동일한 패턴 — 로컬 sqlite만 읽는 화면이라 짧게 잡아도 비용
    // 부담 없음(GameConfig.eggInventoryRefreshInterval 주석 참고). 새 아키텍처(리스너/스트림)
    // 없이 이 기존 폴링 패턴을 그대로 재사용.
    _refreshTimer = Timer.periodic(
      GameConfig.eggInventoryRefreshInterval,
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final eggs = await _eggRepository.getUnhatchedEggs();
    final distanceMeters = await _dailyDistanceRepository
        .getTodayDistanceMeters();
    final lastSyncedAt = await DistanceTrackerService.instance.lastSyncedAt();
    final partnerEggs = eggs.where((egg) => egg.isPartner).toList();
    // 파트너 알이 있을 때만 HC 권한을 확인 — 없으면 거리가 안 늘어도 문제될 게 없어 배너가
    // 불필요. hasPermission()은 UI 없는 조용한 조회라 폴링 주기마다 불러도 부담 없음(회수 시
    // 배너 재등장도 이 재확인 덕분).
    final needsHcConnect = Platform.isAndroid &&
        partnerEggs.isNotEmpty &&
        !(await DistanceTrackerService.instance.hasPermission());
    if (!mounted) return;
    setState(() {
      _partnerEggs = partnerEggs;
      _todayDistanceMeters = distanceMeters;
      _lastSyncedAt = lastSyncedAt;
      _needsHcConnect = needsHcConnect;
    });
  }

  // 인라인 "Health Connect 연결" 배너 탭 — egg_inventory_screen.dart의 파트너 지정 흐름과 동일하게
  // 안내 다이얼로그를 먼저 띄운 뒤 권한/설치 플로우로 넘어간다(예고 없이 Play Store로 튀는 것 방지).
  Future<void> _onConnectHcPressed() async {
    final session = context.read<AuthSession>();
    final proceed = await showHealthConnectNoticeDialog(context);
    if (!proceed || !mounted) return;
    await DistanceTrackerService.instance.start(session);
    await _load();
  }

  // 기본 4분 주기 Health Connect 동기화를 기다리지 않고 유저가 직접 당겨올 수 있는 탈출구
  // (egg_inventory_screen.dart의 동일한 버튼과 같은 이유, Document/temp.md 참고) — syncNow()는
  // 이미 있던 공개 메서드 그대로 재사용.
  Future<void> _onSyncPressed() async {
    setState(() => _syncing = true);
    try {
      await DistanceTrackerService.instance.syncNow();
      await _load();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 전용 접기/펼치기 아이콘 없이 박스 전체(알/빈 슬롯 행 포함)를 탭 대상으로 씀 — 별도
    // 내비게이션이 없어졌으니 안에 중첩 InkWell을 둘 이유도 없어져서 이 InkWell 하나로 충분.
    return Tooltip(
      message: _expanded
          ? l10n.collapsePartnerEggBoxTooltip
          : l10n.expandPartnerEggBoxTooltip,
      child: SketchCard(
        padding: EdgeInsets.zero,
        rotationDegrees: -0.6,
        seed: 2,
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topLeft,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const _CollapsedContent(),
          secondChild: _ExpandedContent(
            partnerEggs: _partnerEggs,
            todayDistanceMeters: _todayDistanceMeters,
            lastSyncedAt: _lastSyncedAt,
            syncing: _syncing,
            onSyncPressed: _onSyncPressed,
            needsHcConnect: _needsHcConnect,
            onConnectHcPressed: _onConnectHcPressed,
          ),
        ),
      ),
    );
  }
}

class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Icon(Icons.egg_outlined),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final List<UserEgg> partnerEggs;
  final double todayDistanceMeters;
  final DateTime? lastSyncedAt;
  final bool syncing;
  final VoidCallback onSyncPressed;
  final bool needsHcConnect;
  final VoidCallback onConnectHcPressed;

  const _ExpandedContent({
    required this.partnerEggs,
    required this.todayDistanceMeters,
    required this.lastSyncedAt,
    required this.syncing,
    required this.onSyncPressed,
    required this.needsHcConnect,
    required this.onConnectHcPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calories = (todayDistanceMeters / 1000 * GameConfig.caloriesPerKm)
        .round();
    return SizedBox(
      width: 180,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < GameConfig.maxPartnerEggs; i++)
              _PartnerSlotRow(
                egg: i < partnerEggs.length ? partnerEggs[i] : null,
                // 첫 번째 슬롯 행 오른쪽 끝에만 동기화 버튼을 둠(사용자 지정 레이아웃) — 두 번째
                // 이후 행은 같은 폭(28)의 빈 공간만 둬서 첫 행과 좌우 정렬이 어긋나지 않게 함.
                trailing: i == 0
                    ? _SyncButton(syncing: syncing, onPressed: onSyncPressed)
                    : const SizedBox(width: 28, height: 28),
              ),
            const Divider(height: 16),
            // 왼쪽 끝 거리 / 오른쪽 끝 칼로리 — 각각 아이콘으로 구분(2026-08-18, 사용자 요청).
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconStat(
                  icon: Icons.directions_walk,
                  label: '${formatKm(todayDistanceMeters)}km',
                ),
                _IconStat(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  label: l10n.todayCaloriesLabel(calories),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _RefreshHint(lastSyncedAt: lastSyncedAt),
            if (needsHcConnect) ...[
              const SizedBox(height: 6),
              _HcConnectBanner(onPressed: onConnectHcPressed),
            ],
          ],
        ),
      ),
    );
  }
}

/// 파트너 알은 있는데 Health Connect 권한이 없어 거리가 안 잡히는 상태에서만 뜨는 인라인 배너 —
/// 탭하면 안내 다이얼로그 → 권한/설치 플로우. 박스 폭(180)이 좁아 짧은 문구 + 한 줄로 유지.
class _HcConnectBanner extends StatelessWidget {
  final VoidCallback onPressed;

  const _HcConnectBanner({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 13,
            color: Colors.deepOrange,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.healthConnectConnectPrompt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: Colors.deepOrange),
        ],
      ),
    );
  }
}

/// "N분 전 갱신 ⓘ" — 거리 수치가 실시간이 아니라 일정 주기로만 갱신된다는 걸 알려주는 한 줄.
/// 탭하면 이유(배터리 절약)와 즉시 갱신 방법을 담은 바텀시트를 연다. 즉시 갱신 버튼 자체는
/// 위쪽 첫 파트너 슬롯 행의 [_SyncButton]에 이미 있음.
class _RefreshHint extends StatelessWidget {
  final DateTime? lastSyncedAt;

  const _RefreshHint({required this.lastSyncedAt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );
    return InkWell(
      onTap: () => showDistanceRefreshInfoSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              distanceRefreshedAgoLabel(l10n, lastSyncedAt),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.info_outline, size: 12, color: style?.color),
        ],
      ),
    );
  }
}

/// 오늘 거리/칼로리 한 줄의 아이콘+숫자 조각 — 두 조각을 좌우 끝에 배치하는 용도.
class _IconStat extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;

  const _IconStat({required this.icon, this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PartnerSlotRow extends StatelessWidget {
  final UserEgg? egg;
  final Widget trailing;

  const _PartnerSlotRow({required this.egg, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final egg = this.egg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: egg == null
                  ? const _EmptyPartnerSlotIcon()
                  : EggImage(rarity: egg.rarity, width: 24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: egg == null
                  ? [
                      Text(
                        l10n.emptyPartnerSlotLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]
                  : [
                      Text(
                        rarityLabel(context, egg.rarity),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        l10n.partnerEggDistanceLabel(
                          formatKm(egg.distanceAccumulatedMeters),
                          formatKm(egg.targetDistanceMeters),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// 기본 동기화 주기(4분)를 기다리지 않고 바로 당겨오는 버튼 — 박스 폭이 좁아 아이콘만 표시
/// (실기기 확인, Document/temp.md "파트너 box 걸음 수 측정" 참고). 바깥 InkWell(접기/펼치기)과
/// 탭 영역이 겹치지만, 이 IconButton이 자기 영역의 탭을 먼저 가져가서 접기/펼치기가 같이
/// 발동하지는 않음.
class _SyncButton extends StatelessWidget {
  final bool syncing;
  final VoidCallback onPressed;

  const _SyncButton({required this.syncing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: l10n.syncDistanceNowTooltip,
        iconSize: 16,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: syncing ? null : onPressed,
        icon: syncing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
      ),
    );
  }
}

/// 빈 파트너 슬롯 표시 — '+' 대신 원형 빗금(diagonal hatch) 아이콘(2026-08-18 결정,
/// Document/temp.md 참고). 파트너로 지정된 알이 2개 미만이면(보유 알이 0개인 경우 포함) 이 아이콘.
class _EmptyPartnerSlotIcon extends StatelessWidget {
  const _EmptyPartnerSlotIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _DiagonalHatchCirclePainter(
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _DiagonalHatchCirclePainter extends CustomPainter {
  final Color color;

  const _DiagonalHatchCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    final hatchPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const gap = 5.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatchPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalHatchCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
