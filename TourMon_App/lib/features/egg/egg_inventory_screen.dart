import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../data/app_database.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../../root_messenger.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../distance/distance_refresh_info_sheet.dart';
import '../distance/distance_tracker_service.dart';
import '../distance/health_connect_notice_dialog.dart';
import '../monster/monster_config_api.dart';
import '../monster/monster_determination.dart';
import '../monster/monster_repository.dart';
import '../monster/monster_species.dart';
import 'distance_format.dart';
import 'egg_image.dart';
import 'egg_odds_overview_dialog.dart';
import 'egg_repository.dart';
import 'egg_type_info_sheet.dart';
import 'hatch_api.dart';
import 'hatch_reveal_screen.dart';
import 'migration_service.dart';
import 'user_egg.dart';

/// 4단계 — 알 보관함/파트너 교체/부화 트리거 화면 (init_plan.md 4-3 섹션).
/// 도감(부화된 몬스터 목록) 화면은 `../monster/dex_screen.dart` 참고.
class EggInventoryScreen extends StatefulWidget {
  const EggInventoryScreen({super.key});

  @override
  State<EggInventoryScreen> createState() => _EggInventoryScreenState();
}

class _EggInventoryScreenState extends State<EggInventoryScreen> {
  final _eggRepository = const EggRepository();
  final _monsterConfigApi = const MonsterConfigApi();
  final _monsterRepository = const MonsterRepository();

  List<UserEgg> _eggs = [];
  DateTime? _lastSyncedAt;
  bool _loading = true;
  bool _syncing = false;
  String? _hatchingEggId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // 이 화면은 로컬 sqlite만 읽고 외부 API를 안 부르니, 거리 진행도를 주기적으로
    // 조용히(스피너 없이) 새로고침 — 백그라운드에서 파트너 알에 거리가 쌓이는 걸
    // 화면을 나갔다 들어오지 않아도 보이게 함.
    _refreshTimer = Timer.periodic(
      GameConfig.eggInventoryRefreshInterval,
      (_) => _load(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    final eggs = await _eggRepository.getUnhatchedEggs();
    final lastSyncedAt = await DistanceTrackerService.instance.lastSyncedAt();
    if (!mounted) return;
    setState(() {
      _eggs = eggs;
      _lastSyncedAt = lastSyncedAt;
      _loading = false;
    });
  }

  // Health Connect 동기화는 기본 4분 주기라 방금 걸은 게 화면에 바로 안 보여서 "버그 아닌가"
  // 오해하기 쉬움(실기기 확인, Document/temp.md 참고) — 유저가 원할 때 직접 한 번 당겨올 수 있는
  // 탈출구. syncNow()는 이미 부화 직전에도 쓰던 기존 공개 메서드라 새 로직 없이 그대로 재사용.
  Future<void> _onSyncPressed() async {
    setState(() => _syncing = true);
    try {
      await DistanceTrackerService.instance.syncNow();
      await _load(showLoading: false);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _onPartnerToggled(UserEgg egg, bool wantPartner) async {
    final l10n = AppLocalizations.of(context)!; // await 전에 미리 확보 — 아래 참고
    final session = context.read<AuthSession>();

    if (wantPartner) {
      // 슬롯 초과면 여기서 끝 — Health Connect 안내도, DB 쓰기도 하지 않는다.
      if (await _eggRepository.countPartners() >= GameConfig.maxPartnerEggs) {
        _showSnackBar(l10n.partnerLimitError(GameConfig.maxPartnerEggs));
        return;
      }
      // 파트너 알을 처음(또는 다시) 지정하는 시점 — Health Connect 권한을 여기서 처음 요청
      // (Document/temp.md 미결 사항 "just-in-time" 결정). 권한이 아직 없을 때만 먼저 안내를
      // 띄우고, 여기서 취소하면 파트너 플래그를 아예 쓰지 않는다 — 버튼을 눌렀다가 취소했는데도
      // 파트너로 설정돼버리던 문제 수정(setPartner를 안내보다 먼저 호출하던 순서 때문이었음).
      // 예고 없이 곧장 Play Store 설치 화면으로 넘어가 당황스러웠던 문제도 이 안내로 방지.
      final alreadyGranted = await DistanceTrackerService.instance
          .hasPermission();
      if (!alreadyGranted) {
        if (!mounted) return;
        final proceed = await showHealthConnectNoticeDialog(context);
        if (!proceed) return;
      }
    }

    final ok = await _eggRepository.setPartner(egg.id, wantPartner);
    if (!ok) {
      // countPartners 확인과 setPartner 사이 경합으로 초과된 드문 경우.
      _showSnackBar(l10n.partnerLimitError(GameConfig.maxPartnerEggs));
    } else if (wantPartner) {
      if (!mounted) return;
      // 여기서 실제 OS 권한 요청이 일어남(이미 서비스가 돌고 있으면 내부에서 조용히 무시).
      // 권한 거부/설치 취소로 Health Connect를 못 쓰면 파트너 알은 걸은 거리로 자랄 수 없으므로
      // 방금 건 파트너 지정을 되돌린다.
      final started = await DistanceTrackerService.instance.start(session);
      if (!started) {
        await _eggRepository.setPartner(egg.id, false);
        _showSnackBar(l10n.healthConnectDeniedPartnerCancelledMessage);
      }
    }
    await _load();
  }

  /// 6단계 Phase 5 — 부화 경로 결정. 게스트면 로컬 determineMonster(), 로그인 상태면 서버
  /// authoritative 부화(HatchApi)(init_plan.md 4-3 "목표 거리 달성 판정 및 부화 처리" 🖥️🔐 —
  /// 회원은 거리 조작 방지를 위해 서버가 최종 판정, 게스트는 계정 자체가 없어 로컬 결정 유지).
  ///
  /// 단, 로그인 상태라도 이 알이 게스트 때 획득분이고 아직 계정으로 이관되지 않았으면
  /// (`syncedAt == null`) 서버 부화가 404남 — 부화 직전에 재이관을 한 번 더 시도하고, 그래도
  /// 안 되면 서버 hatch를 부르지 않고 예외를 던진다(2026-08-30, 6-4 문서 "부화 직전 재이관 가드").
  Future<MonsterSpecies> _determineSpecies(
    UserEgg egg,
    AuthSession session,
    String locale,
  ) async {
    if (!session.isLoggedIn) {
      final config = await _monsterConfigApi.fetchConfig(locale: locale);
      return determineMonster(
        eggRarity: egg.rarity,
        contentTypeId: egg.contentTypeId,
        config: config,
      );
    }
    final client = AuthorizedApiClient(session, locale: locale);

    // 로그인은 했지만 이 알이 게스트 때 획득분이라 아직 계정으로 이관되지 않았으면(synced_at IS
    // NULL) 서버 user_eggs에 없어서 부화가 404(HatchNotFoundException)남 — 로그인 직후
    // syncGuestDataWithServer의 마이그레이션이 네트워크로 실패해 삼켜졌거나, voucher가
    // rejected(만료/불일치)돼 synced_at이 안 박힌 경우. 부화 직전에 한 번 더 이관을 시도하고,
    // 재조회해도 여전히 미이관/삭제면 서버 hatch를 아예 부르지 않고 사용자에게 알린다.
    if (egg.syncedAt == null) {
      await const MigrationService().migrateIfNeeded(client);
      final refreshed = await _eggRepository.getById(egg.id);
      if (refreshed == null) throw HatchEggExpiredException();
      if (refreshed.syncedAt == null) throw HatchEggNotOnAccountException();
    }

    // 로컬은 "준비됨"으로 보여도 서버 거리 동기화(배치, 최대 몇 분 지연)가 아직 못 따라잡았을 수
    // 있음 — 부화 시도 직전에 한 번 강제로 동기화해서 이 시차로 인한 불필요한 실패를 줄임.
    await DistanceTrackerService.instance.syncNow();
    return HatchApi(client).hatch(egg.id);
  }

  /// 유통기한이 지난 게스트 알을 보관함에서 제거 — 사용자가 "치우기"를 눌렀을 때
  /// (init_plan.md "클라이언트 측 선제 체크"). 서버 강제력은 egg_vouchers 삭제에 있고 이건 UX 장치.
  Future<void> _onDiscardExpired(UserEgg egg) async {
    final l10n = AppLocalizations.of(context)!;
    await _eggRepository.deleteEgg(egg.id);
    _showSnackBar(l10n.guestEggDiscardedMessage);
    await _load();
  }

  Future<void> _onHatchPressed(UserEgg egg) async {
    final session = context.read<AuthSession>(); // 아래 await들 전에 미리 확보
    final l10n = AppLocalizations.of(context)!; // 마찬가지로 비동기 갭 전에 미리 확보
    final locale = apiLocaleOf(context);
    // 게스트 알이 유통기한을 넘겼으면 부화를 막고 여기서 치움 — "회원가입 시 뜬금없는 거부"가
    // 아니라 "부화 시도 시점의 게임 내 이벤트"로 실패 시점을 앞당김(init_plan.md). 정상 플레이에선
    // 만료 알에 부화 버튼 자체가 안 뜨므로(_EggCard), 로딩 직후~탭 사이 경계에서만 타는 방어 경로.
    if (!session.isLoggedIn && egg.isGuestShelfLifeExpired) {
      await _eggRepository.deleteEgg(egg.id);
      _showSnackBar(l10n.guestEggExpiredHatchAttemptMessage);
      await _load();
      return;
    }
    setState(() => _hatchingEggId = egg.id);
    try {
      final species = await _determineSpecies(egg, session, locale);
      // 로그인 상태 부화는 서버(hatch/route.ts)가 이미 authoritative하게 몬스터를 생성하고 알을
      // 소진했으므로, 로컬 row에도 synced_at을 박아 다음 로그인의 마이그레이션 대상에서 뺌 —
      // 특히 서버가 만든 몬스터 id와 아래에서 만드는 로컬 id가 달라서, 안 박으면 이 로컬 몬스터가
      // 매 로그인마다 전송됐다가 egg_id unique 충돌로 거부되는 노이즈가 생김(migration_service.dart).
      final syncedAt = session.isLoggedIn ? DateTime.now() : null;
      // 몬스터 생성 + 알 소진을 하나의 트랜잭션으로 묶음 — 둘 중 하나만 반영되면(예: 앱이 중간에
      // 종료됨) 알이 안 없어진 채로 남아서 재시도 시 몬스터가 중복 생성될 수 있음(init_plan.md
      // 4-3 섹션의 원자성 원칙을 로컬 저장에도 동일 적용 — 로그인 상태여도 화면은 여전히 로컬
      // sqlite를 읽으므로, 서버가 이미 authoritative하게 결정한 species를 로컬에도 그대로 반영).
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await _monsterRepository.insertHatchedMonster(
          species: species,
          eggId: egg.id,
          tourismSpotId: egg.tourismSpotId,
          tourismSpotTitle: egg.tourismSpotTitle,
          syncedAt: syncedAt,
          executor: txn,
        );
        await _eggRepository.markHatched(egg.id, DateTime.now(), executor: txn);
        if (syncedAt != null) {
          await _eggRepository.markSynced([egg.id], executor: txn);
        }
      });
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => HatchRevealScreen(species: species),
        ),
      );
    } on HatchNotReadyException {
      _showSnackBar(l10n.hatchNotReadyMessage);
    } on HatchAlreadyDoneException {
      _showSnackBar(l10n.hatchAlreadyDoneMessage);
    } on HatchEggExpiredException {
      // migrateIfNeeded가 만료된 알을 로컬에서도 지웠음 — finally의 _load()로 목록에서 사라짐.
      _showSnackBar(l10n.guestEggExpiredHatchAttemptMessage);
    } on HatchEggNotOnAccountException {
      _showSnackBar(l10n.hatchEggNotOnAccountMessage);
    } on HatchNotFoundException {
      // syncedAt이 채워졌는데도 서버가 404 — 재이관 가드(_determineSpecies)를 지나쳐 여기까지
      // 오는 건 계정 불일치/서버 row 소실 같은 이례적 상태. 최소한 raw 예외 문자열 대신 안내를 줌.
      _showSnackBar(l10n.hatchEggNotOnAccountMessage);
    } catch (e) {
      _showSnackBar(l10n.hatchFailedMessage('$e'));
    } finally {
      if (mounted) setState(() => _hatchingEggId = null);
      await _load();
    }
  }

  // 이 화면은 Navigator.push로 쌓인 화면이라, 부화/파트너 전환은 네트워크 왕복(await) 중에
  // 사용자가 뒤로 가버릴 수 있음 — 로컬 ScaffoldMessenger.of(context)로는 그 사이 dispose된
  // 화면에 못 띄우므로 앱 전역 메신저(root_messenger.dart)를 씀(my_page_screen.dart와 동일 이유).
  void _showSnackBar(String message) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 게스트(로그인 전)만 알 유통기한 안내/판정 대상 — 회원 user_eggs엔 TTL이 없음
    // (init_plan.md DB 스키마 egg_vouchers 섹션).
    final isGuest = !context.watch<AuthSession>().isLoggedIn;
    // 지도 화면과 같은 그림책+연필 스케치 테마를 이 화면 서브트리에만 지역 적용
    // (2026-08-26, 사용자 요청 — config/sketch/sketch_theme.dart 주석 참고).
    return Theme(
      data: SketchTheme.themeData,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(l10n.eggInventoryTitle)),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: l10n.eggOddsOverviewButtonTooltip,
                onPressed: () => showEggOddsOverviewDialog(context),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.syncDistanceNowTooltip,
              onPressed: _syncing ? null : _onSyncPressed,
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: _RefreshHintBar(lastSyncedAt: _lastSyncedAt),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _eggs.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text(l10n.noEggsMessage)),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (isGuest) const _GuestShelfLifeBanner(),
                          for (final egg in _eggs)
                            _EggCard(
                              egg: egg,
                              isGuest: isGuest,
                              isHatching: _hatchingEggId == egg.id,
                              onPartnerToggled: (value) =>
                                  _onPartnerToggled(egg, value),
                              onHatchPressed: () => _onHatchPressed(egg),
                              onDiscardExpired: () => _onDiscardExpired(egg),
                            ),
                        ],
                      ),
              ),
      ),
    );
  }
}

/// AppBar 하단의 얇은 안내 줄 — 거리 진행도가 실시간이 아니라 배터리 절약을 위해 일정 주기로만
/// 갱신된다는 것과 마지막 갱신 시각을 보여주고, 탭하면 즉시 갱신 방법까지 담은 바텀시트를 연다.
/// 즉시 갱신 버튼은 AppBar 우측 [Icons.sync] + 목록 당겨서 새로고침으로 이미 제공됨.
class _RefreshHintBar extends StatelessWidget {
  final DateTime? lastSyncedAt;

  const _RefreshHintBar({required this.lastSyncedAt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final minutes = GameConfig.distanceServerSyncInterval.inMinutes;
    final color = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return InkWell(
      onTap: () => showDistanceRefreshInfoSheet(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            Icon(Icons.battery_saver, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${l10n.distanceRefreshEveryMinutes(minutes)} · '
                '${distanceRefreshedAgoLabel(l10n, lastSyncedAt)}',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 13, color: color),
          ],
        ),
      ),
    );
  }
}

class _EggCard extends StatelessWidget {
  final UserEgg egg;
  final bool isGuest;
  final bool isHatching;
  final ValueChanged<bool> onPartnerToggled;
  final VoidCallback onHatchPressed;
  final VoidCallback onDiscardExpired;

  const _EggCard({
    required this.egg,
    required this.isGuest,
    required this.isHatching,
    required this.onPartnerToggled,
    required this.onHatchPressed,
    required this.onDiscardExpired,
  });

  void _openInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EggTypeInfoSheet(egg: egg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = (egg.distanceAccumulatedMeters / egg.targetDistanceMeters)
        .clamp(0.0, 1.0);
    final expired = isGuest && egg.isGuestShelfLifeExpired;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SketchCard(
        padding: EdgeInsets.zero,
        fillColor: SketchTheme.paperLight,
        seed: egg.id.hashCode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Opacity(
                  opacity: expired ? 0.5 : 1,
                  child: EggImage(rarity: egg.rarity, width: 72),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    egg.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
                                  tooltip: l10n.eggInfoButtonTooltip,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _openInfoSheet(context),
                                ),
                              ],
                            ),
                            Text(
                              l10n.distanceProgress(
                                rarityLabel(context, egg.rarity),
                                formatKm(egg.distanceAccumulatedMeters),
                                formatKm(egg.targetDistanceMeters),
                              ),
                            ),
                            if (isGuest) ...[
                              const SizedBox(height: 3),
                              _ShelfLifeLine(egg: egg, expired: expired),
                            ],
                          ],
                        ),
                      ),
                      // 굳어버린 알은 파트너로 걸어봐야 부화가 안 되므로 토글 자체를 숨김.
                      if (expired)
                        const SizedBox.shrink()
                      else
                        Tooltip(
                          message: l10n.partnerToggleTooltip,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onPartnerToggled(!egg.isPartner),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    egg.isPartner
                                        ? Icons.check_circle
                                        : Icons.check_circle_outline,
                                    size: 20,
                                    color: egg.isPartner
                                        ? SketchTheme.accent
                                        : SketchTheme.ink.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.partnerToggleLabel,
                                    style: TextStyle(
                                      fontWeight: egg.isPartner
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: egg.isPartner
                                          ? SketchTheme.ink
                                          : SketchTheme.ink.withValues(
                                              alpha: 0.4,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  if (expired) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onDiscardExpired,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(l10n.discardExpiredEggButton),
                      ),
                    ),
                  ] else if (egg.isReadyToHatch) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SketchButton(
                        onPressed: isHatching ? null : onHatchPressed,
                        leading: isHatching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SketchTheme.paper,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: SketchTheme.paper,
                                size: 18,
                              ),
                        label: l10n.hatchButton,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 게스트 알 카드의 유통기한 한 줄 — 남은 일수(경고 구간이면 강조색) 또는 "굳음" 상태.
class _ShelfLifeLine extends StatelessWidget {
  final UserEgg egg;
  final bool expired;

  const _ShelfLifeLine({required this.egg, required this.expired});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (expired) {
      return Text(
        l10n.guestEggExpiredLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    final remaining = egg.guestShelfLifeRemaining;
    final warn = remaining <= GameConfig.guestEggExpiryWarningWindow;
    final color = warn
        ? const Color(0xFFB4530A) // 스케치 테마 팔레트에 경고색이 없어 여기서만 앰버 계열 지정
        : SketchTheme.ink.withValues(alpha: 0.55);
    final text = remaining.inDays >= 1
        ? l10n.guestEggExpiresInDays(remaining.inDays)
        : l10n.guestEggExpiresTodayLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hourglass_bottom, size: 12, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: warn ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// 게스트 알 보관함 상단 안내 — 로그인 전 알은 유통기한이 있고, 로그인하면 영구 보관됨을 알림.
class _GuestShelfLifeBanner extends StatelessWidget {
  const _GuestShelfLifeBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SketchTheme.paperLight,
        border: Border.all(color: SketchTheme.ink.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: SketchTheme.ink.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.guestEggShelfLifeBanner(GameConfig.guestEggShelfLife.inDays),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SketchTheme.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
