import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../data/tourism_spot_repository.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../egg/egg_api.dart';
import '../egg/egg_repository.dart';
import 'duplicate_spots_sheet.dart';
import 'tourism_api.dart';
import 'tourism_spot.dart';

/// 마커 탭 시 뜨는 미리보기(+"더보기" 상세) 바텀시트. 4-2 섹션: 미리보기는 이미 가진 데이터로
/// 즉시 표시, "더보기" 탭 시에만 상세 API(detailCommon2/detailImage2 프록시) 호출.
class TourismSpotSheet extends StatefulWidget {
  final TourismSpot spot;
  // 좌표 중복 리스트(duplicate_spots_sheet.dart)의 개별 항목에서 열렸을 때만 대표 spot id로 채워짐.
  // 알 획득 쿨타임/저장은 항상 이 값(없으면 spot.id 그대로) 기준으로 해야 함 — 안 그러면 게스트 모드는
  // 서버 쿨타임 검증이 아예 없어서(egg_repository.dart 상단 주석 참고) 유저가 리스트의 자식 항목을
  // 매일 갈아타며 무한정 알을 받을 수 있음(later.md/temp.md "관광지 마커 — 좌표 중복" A안이 막으려던
  // 어뷰징이 게스트 모드에서 그대로 재현됨).
  final int? cooldownSpotId;

  const TourismSpotSheet({super.key, required this.spot, this.cooldownSpotId});

  @override
  State<TourismSpotSheet> createState() => _TourismSpotSheetState();
}

class _TourismSpotSheetState extends State<TourismSpotSheet> {
  final _api = const TourismApi();
  final _tourismSpotRepository = const TourismSpotRepository();
  final _eggRepository = const EggRepository();
  Future<TourismSpotDetail>? _detailFuture;
  Future<TourismSpotMembers>? _membersFuture;
  bool _isAcquiringEgg = false;
  String? _eggResultMessage;

  @override
  void initState() {
    super.initState();
    // 좌표 중복(같은 건물 내 여러 매장) 그룹의 대표일 때만 카테고리 아이콘을 보여주기 위해 미리 조회 —
    // memberCount는 로컬 캐시(dedup 배치가 미리 계산해 내려준 값)에서만 채워짐, 1이면 solo spot이라
    // 호출 안 함. 네트워크 없이 로컬 sqlite 쿼리라 즉시 반환되지만, 기존 FutureBuilder 구조를
    // 그대로 재사용하기 위해 Future로 감쌈.
    if (widget.spot.memberCount > 1) {
      _membersFuture = _tourismSpotRepository.getMembers(widget.spot.id);
    }
  }

  // AuthorizedApiClient는 AuthSession(전역 Provider) 의존성이 생겨서 더 이상 const 필드로 못 만듦 —
  // 로그인 상태면 자동으로 Authorization 헤더가 붙어야 하므로 매번 현재 세션으로 새로 구성
  // (Document/study_folder/6-4_게스트 회원가입 마이그레이션.md).
  EggApi _eggApi(BuildContext context) => EggApi(
        AuthorizedApiClient(context.read<AuthSession>(), locale: apiLocaleOf(context)),
      );

  void _loadDetail() {
    setState(() {
      _detailFuture = _api.fetchSpotDetail(widget.spot.id, locale: apiLocaleOf(context));
    });
  }

  // build()의 표시용과 알 획득 시 스냅샷 저장용 둘 다 이 로직을 그대로 써야, 영문 로케일에서
  // 획득한 알의 도감 기록도 영문 장소명으로 남는다(실기기 확인 중 발견 — 스냅샷 캡처가 이 로직을
  // 안 타고 항상 spot.title만 썼던 버그). 규칙 자체는 `displayTitleOf`(l10n/api_locale.dart)에
  // 있어서 다른 화면(duplicate_spots_sheet.dart 등)과 공유.
  String _displayTitle(BuildContext context) {
    final spot = widget.spot;
    return displayTitleOf(context, title: spot.title, titleEn: spot.titleEn);
  }

  int get _cooldownSpotId => widget.cooldownSpotId ?? widget.spot.id;

  Future<void> _onAcquireEggPressed() async {
    final l10n = AppLocalizations.of(context)!; // 아래 await들 전에 미리 확보(비동기 갭 이후 context 사용 지양)
    final tourismSpotTitle = _displayTitle(context);
    final eggApi = _eggApi(context);
    setState(() => _isAcquiringEgg = true);
    try {
      if (await _eggRepository.hasAcquiredToday(_cooldownSpotId)) {
        _showMessage(l10n.alreadyAcquiredTodayMessage);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final result = await eggApi.acquireEgg(
        tourismSpotId: _cooldownSpotId,
        lat: position.latitude,
        lng: position.longitude,
      );

      await _eggRepository.insertEgg(
        overrideId: result.id,
        tourismSpotId: _cooldownSpotId,
        tourismSpotTitle: tourismSpotTitle,
        contentTypeId: widget.spot.contentTypeId,
        eggTypeId: result.eggTypeId,
        rarity: result.rarity,
        name: result.name,
        description: result.description,
        targetSteps: result.targetSteps,
      );

      if (!mounted) return;
      _showMessage(l10n.eggAcquiredMessage(result.name, rarityLabel(context, result.rarity)));
    } on EggLocationInvalidException {
      // 판정 반경은 서버 설정값(game-config.ts의 EGG_ACQUISITION_RADIUS_METERS)에만 있음 —
      // 클라이언트에 중복 하드코딩 안 함.
      _showMessage(l10n.locationInvalidMessage);
    } on EggSpotNotFoundException {
      _showMessage(l10n.spotNotFoundMessage);
    } on EggCooldownException {
      // 정상 플레이에선 위 hasAcquiredToday 프리체크가 먼저 막아서 거의 안 타는 경로 — 서버
      // 쿨타임(로그인 상태 전용)이 클라이언트 프리체크를 우회한 요청을 걸러낸 경우.
      _showMessage(l10n.alreadyAcquiredTodayMessage);
    } on EggAcquisitionDisabledException {
      // 정상 플레이에선 버튼이 이미 비활성화돼 있어(canAcquireEgg) 거의 안 타는 경로.
      _showMessage(l10n.eggAcquisitionDisabledMessage);
    } catch (e) {
      _showMessage(l10n.eggAcquireFailedMessage('$e'));
    } finally {
      if (mounted) setState(() => _isAcquiringEgg = false);
    }
  }

  // showModalBottomSheet 위에서는 SnackBar가 시트 뒤에 가려져 안 보이는 Flutter의 알려진
  // 동작 때문에, 결과를 시트 안에 직접 표시함(별도 오버레이 대신 인라인 텍스트).
  void _showMessage(String message) {
    if (!mounted) return;
    setState(() => _eggResultMessage = message);
  }

  // members가 이미 전체 spots를 갖고 있으면(항목 수가 임계치 이하라 서버가 다 내려준 경우) 그걸
  // 그대로 필터링해서 넘겨 추가 네트워크 호출을 건너뜀 — 없으면(카테고리 버튼만 온 경우) null을
  // 넘겨서 DuplicateSpotsSheet가 contentTypeId로 다시 조회하게 함.
  void _openCategory(TourismSpotMembers members, int contentTypeId) {
    final preloaded = members.spots.where((s) => s.contentTypeId == contentTypeId).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DuplicateSpotsSheet(
        representativeId: widget.spot.id,
        contentTypeId: contentTypeId,
        preloadedSpots: preloaded.isNotEmpty ? preloaded : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spot = widget.spot;
    final displayTitle = _displayTitle(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spot.firstImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: spot.firstImage!,
                  height: 160,
                  width: double.infinity,
                  memCacheHeight: 320,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            Text(displayTitle, style: Theme.of(context).textTheme.titleLarge),
            if (spot.addr1 != null) ...[
              const SizedBox(height: 4),
              Text(
                [spot.addr1, spot.addr2].where((e) => e != null && e.isNotEmpty).join(' '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            // 좌표 중복(같은 건물 내 여러 매장) 그룹의 대표일 때만 노출 — "묶인 관광지 보기" 버튼
            // 대신 카테고리 아이콘을 바로 보여줌(2026-08-17 UI 개선, 사용자 요청).
            if (_membersFuture != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<TourismSpotMembers>(
                future: _membersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 56,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(l10n.duplicateSpotsLoadFailedMessage('${snapshot.error}'));
                  }
                  final members = snapshot.data!;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in members.byContentType)
                        CategoryIconTile(
                          contentTypeId: entry.contentTypeId,
                          count: entry.count,
                          onTap: () => _openCategory(members, entry.contentTypeId),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (!canAcquireEgg(spot.contentTypeId) || _isAcquiringEgg)
                  ? null
                  : _onAcquireEggPressed,
              icon: _isAcquiringEgg
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.egg_outlined),
              label: Text(l10n.acquireEggButton),
            ),
            if (!canAcquireEgg(spot.contentTypeId)) ...[
              const SizedBox(height: 8),
              Text(
                l10n.eggAcquisitionDisabledMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (_eggResultMessage != null) ...[
              const SizedBox(height: 8),
              Text(_eggResultMessage!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            if (_detailFuture == null)
              OutlinedButton(onPressed: _loadDetail, child: Text(l10n.showMoreButton))
            else
              FutureBuilder<TourismSpotDetail>(
                future: _detailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(l10n.detailLoadFailedMessage('${snapshot.error}'));
                  }
                  final detail = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.overview != null) Text(detail.overview!),
                      if (detail.homepage != null && detail.homepage!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          detail.homepage!,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
                      if (detail.images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: detail.images.length,
                            itemBuilder: (context, index) {
                              final image = detail.images[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: image.smallImageUrl,
                                    width: 100,
                                    height: 100,
                                    fit: image.allowsCrop
                                        ? BoxFit.cover
                                        : BoxFit.contain,
                                    memCacheWidth: 200,
                                    errorWidget: (context, url, error) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 카테고리 하나를 아이콘+개수 뱃지+라벨로 보여주는 탭 가능한 타일 — 텍스트 리스트보다 한눈에
/// 훑기 쉬움(2026-08-17 UI 개선). duplicate_spots_sheet.dart에서도 재사용하므로 public.
class CategoryIconTile extends StatelessWidget {
  final int contentTypeId;
  final int count;
  final VoidCallback onTap;

  const CategoryIconTile({
    super.key,
    required this.contentTypeId,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Icon(contentTypeIcon(contentTypeId)),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.redAccent,
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              contentTypeLabel(context, contentTypeId),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
