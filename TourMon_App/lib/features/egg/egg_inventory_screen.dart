import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/game_config.dart';
import '../../data/app_database.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../../root_messenger.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../monster/monster_config_api.dart';
import '../monster/monster_determination.dart';
import '../monster/monster_repository.dart';
import '../monster/monster_species.dart';
import '../steps/step_tracker_service.dart';
import 'egg_image.dart';
import 'egg_repository.dart';
import 'egg_type_info_sheet.dart';
import 'hatch_api.dart';
import 'hatch_reveal_screen.dart';
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
  bool _loading = true;
  String? _hatchingEggId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // 이 화면은 로컬 sqlite만 읽고 외부 API를 안 부르니, 걸음수 진행도를 주기적으로
    // 조용히(스피너 없이) 새로고침 — 백그라운드에서 파트너 알에 걸음수가 쌓이는 걸
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
    if (!mounted) return;
    setState(() {
      _eggs = eggs;
      _loading = false;
    });
  }

  Future<void> _onPartnerToggled(UserEgg egg, bool wantPartner) async {
    final l10n = AppLocalizations.of(context)!; // await 전에 미리 확보 — 아래 참고
    final ok = await _eggRepository.setPartner(egg.id, wantPartner);
    if (!ok) {
      _showSnackBar(l10n.partnerLimitError(GameConfig.maxPartnerEggs));
    }
    await _load();
  }

  /// 6단계 Phase 5 — 로그인 상태면 서버 authoritative 부화(HatchApi), 게스트면 기존처럼 로컬
  /// determineMonster()(init_plan.md 4-3 "목표 걸음수 달성 판정 및 부화 처리" 🖥️🔐 — 회원은 걸음수
  /// 조작 방지를 위해 서버가 최종 판정, 게스트는 서버에 계정 자체가 없어 그대로 로컬 결정 유지).
  Future<MonsterSpecies> _determineSpecies(UserEgg egg, AuthSession session, String locale) async {
    if (!session.isLoggedIn) {
      final config = await _monsterConfigApi.fetchConfig(locale: locale);
      return determineMonster(
        eggRarity: egg.rarity,
        contentTypeId: egg.contentTypeId,
        config: config,
      );
    }
    // 로컬은 "준비됨"으로 보여도 서버 걸음수 동기화(배치, 최대 몇 분 지연)가 아직 못 따라잡았을 수
    // 있음 — 부화 시도 직전에 한 번 강제로 밀어넣어서 이 시차로 인한 불필요한 실패를 줄임.
    await StepTrackerService.instance.syncPendingStepsToServer();
    final client = AuthorizedApiClient(session, locale: locale);
    return HatchApi(client).hatch(egg.id);
  }

  Future<void> _onHatchPressed(UserEgg egg) async {
    final session = context.read<AuthSession>(); // 아래 await들 전에 미리 확보
    final l10n = AppLocalizations.of(context)!; // 마찬가지로 비동기 갭 전에 미리 확보
    final locale = apiLocaleOf(context);
    setState(() => _hatchingEggId = egg.id);
    try {
      final species = await _determineSpecies(egg, session, locale);
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
          executor: txn,
        );
        await _eggRepository.markHatched(egg.id, DateTime.now(), executor: txn);
      });
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => HatchRevealScreen(species: species)),
      );
    } on HatchNotReadyException {
      _showSnackBar(l10n.hatchNotReadyMessage);
    } on HatchAlreadyDoneException {
      _showSnackBar(l10n.hatchAlreadyDoneMessage);
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
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.eggInventoryTitle)),
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _eggs.length,
                      itemBuilder: (context, index) => _EggCard(
                        egg: _eggs[index],
                        isHatching: _hatchingEggId == _eggs[index].id,
                        onPartnerToggled: (value) => _onPartnerToggled(_eggs[index], value),
                        onHatchPressed: () => _onHatchPressed(_eggs[index]),
                      ),
                    ),
            ),
    );
  }
}

class _EggCard extends StatelessWidget {
  final UserEgg egg;
  final bool isHatching;
  final ValueChanged<bool> onPartnerToggled;
  final VoidCallback onHatchPressed;

  const _EggCard({
    required this.egg,
    required this.isHatching,
    required this.onPartnerToggled,
    required this.onHatchPressed,
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
    final progress = (egg.stepsAccumulated / egg.targetSteps).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: EggImage(rarity: egg.rarity, width: 72)),
          ),
          const Divider(height: 1),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 18),
                                tooltip: l10n.eggInfoButtonTooltip,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openInfoSheet(context),
                              ),
                            ],
                          ),
                          Text(l10n.stepsProgress(
                            rarityLabel(context, egg.rarity),
                            egg.stepsAccumulated,
                            egg.targetSteps,
                          )),
                        ],
                      ),
                    ),
                    Switch(
                      value: egg.isPartner,
                      onChanged: onPartnerToggled,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 8),
                ),
                if (egg.isReadyToHatch) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: isHatching ? null : onHatchPressed,
                      icon: isHatching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(l10n.hatchButton),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
