import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_session.dart';
import 'egg_repository.dart';

/// 디버그 전용(`--dart-define=DEBUG_MODE=true`) — 관광지/GPS/서버 판정 없이 알을 로컬에 하나
/// 추가한다. 누를 때마다 등급을 common→rare→epic→legendary 순으로 돌려서 만든다(모든 등급의
/// 카드 레이아웃 · 부화 진행도 · 확률표를 빠르게 확인하는 용도).
///
/// 정식 획득 경로(tourism_spot_sheet.dart)와 달리 서버 `egg_vouchers` row가 없으므로 **로그인
/// 상태에서는 이 알을 부화할 수 없다**(서버 authoritative 부화가 404 → HatchEggNotOnAccount).
/// 부화까지 확인하려면 게스트 상태에서 쓰거나 실제 획득 경로를 탈 것. 로그인 상태면 synced_at을
/// 박아, 마이그레이션이 서버로 밀어보냈다가 voucher 불일치로 rejected 로그만 남기는 걸 피한다.
class DebugAddEggButton extends StatelessWidget {
  const DebugAddEggButton({super.key});

  static const _rarities = ['common', 'rare', 'epic', 'legendary'];

  // TourMon/scripts/seed.ts의 EGG_TYPES 미러 — 정식 경로에선 서버 획득 응답의
  // targetDistanceMeters가 authoritative지만, 이 버튼은 서버를 안 거치므로 디버그
  // placeholder로만 들고 있음(등급 간 비율 1:3:4.5:6).
  static const _targetDistanceByRarity = {
    'common': 1000,
    'rare': 3000,
    'epic': 4500,
    'legendary': 6000,
  };

  // 누를 때마다 다음 등급으로. 디버그 버튼이라 static 가변 필드로 충분.
  static int _nextRarityIndex = 0;

  static const _eggRepository = EggRepository();

  Future<void> _addEgg(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final loggedIn = context.read<AuthSession>().isLoggedIn;
    final rarity = _rarities[_nextRarityIndex % _rarities.length];
    _nextRarityIndex++;
    try {
      await _eggRepository.insertEgg(
        tourismSpotId: 0, // 실제 스팟 id와 안 겹치는 sentinel(쿨타임/배지 조회에 무해)
        tourismSpotTitle: '[디버그] 알',
        contentTypeId: 12, // 관광지
        eggTypeId: 0,
        rarity: rarity,
        name: '[디버그] $rarity 알',
        description: null,
        targetDistanceMeters: _targetDistanceByRarity[rarity]!,
        syncedAt: loggedIn ? DateTime.now() : null,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('[디버그] $rarity 알 추가됨 — 보관함에서 확인')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('[디버그] 알 추가 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'debug_add_egg',
      onPressed: () => _addEgg(context),
      tooltip: '[디버그] 알 추가(등급 순환)',
      child: const Icon(Icons.egg_alt),
    );
  }
}
