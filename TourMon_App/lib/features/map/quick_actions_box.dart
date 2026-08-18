import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../auth/account_button.dart';
import '../egg/egg_inventory_screen.dart';
import '../monster/dex_screen.dart';

/// 지도 화면 우상단 — 알 보관함/도감/계정 진입점을 모은 접기/펼치기 박스. 원래 AppBar에 있던 세
/// 아이콘을 헤더 제거(2026-08-18, 사용자 요청)에 맞춰 그대로 옮겨온 것뿐이라 각 항목의 동작 자체는
/// 무변경. 왼쪽 파트너 알 박스(박스 전체를 탭해서 토글, 아이콘 없음)와 반대로, 여기는 탐색용
/// 메뉴라 접기/펼치기를 위한 아이콘을 명시적으로 보여줌.
class QuickActionsBox extends StatefulWidget {
  const QuickActionsBox({super.key});

  @override
  State<QuickActionsBox> createState() => _QuickActionsBoxState();
}

class _QuickActionsBoxState extends State<QuickActionsBox> {
  // 원래 AppBar 아이콘이 항상 보이던 것과 동일하게, 기본값은 펼침(2026-08-18, 사용자 요청 —
  // 처음엔 "탐색 메뉴는 평소엔 접어두자"로 기본 접힘으로 시작했었음).
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topRight,
        crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: l10n.expandQuickActionsBoxTooltip,
          onPressed: () => setState(() => _expanded = true),
        ),
        secondChild: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.collapseQuickActionsBoxTooltip,
              onPressed: () => setState(() => _expanded = false),
            ),
            // 마이페이지를 최상단에 배치(2026-08-18, 사용자 요청).
            const AccountButton(),
            IconButton(
              icon: const Icon(Icons.egg_outlined),
              tooltip: l10n.eggInventoryTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const EggInventoryScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: l10n.dexTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DexScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
