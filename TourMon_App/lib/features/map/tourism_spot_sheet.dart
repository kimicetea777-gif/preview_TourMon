import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../audio/sfx.dart';
import '../../config/game_config.dart';
import '../../config/map_config.dart';
import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../data/tourism_spot_repository.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import '../egg/egg_api.dart';
import '../egg/egg_repository.dart';
import 'duplicate_spots_sheet.dart';
import 'location_permission.dart';
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
  // "더보기"로 펼친 상태 — _detailFuture는 한 번 로드하면 그대로 재사용하고(접었다 펴도 재요청
  // 안 함), 이 플래그로만 표시/숨김을 토글한다.
  bool _detailExpanded = false;
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
    AuthorizedApiClient(
      context.read<AuthSession>(),
      locale: apiLocaleOf(context),
    ),
  );

  void _toggleDetail() {
    setState(() {
      if (_detailExpanded) {
        _detailExpanded = false;
        return;
      }
      _detailExpanded = true;
      _detailFuture ??= _api.fetchSpotDetail(
        widget.spot.id,
        locale: apiLocaleOf(context),
      );
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
    final l10n = AppLocalizations.of(
      context,
    )!; // 아래 await들 전에 미리 확보(비동기 갭 이후 context 사용 지양)
    // 인앱 위치 동의 + OS 위치 서비스/권한을 한 번에 게이트(지도 FAB와 공유). 알 획득은 위치가
    // 본질인 동작이라, FAB를 안 누르고 곧장 여기로 온 사용자에게도 이 시점에 OS 권한을 요청한다
    // — 예전엔 권한이 없으면 getCurrentPosition()이 그냥 예외를 던져 "획득 실패"만 떴었음.
    final gate = await ensureLocationReady(context);
    if (!mounted) return;
    if (gate != LocationGateResult.granted) {
      final message = locationGateMessage(l10n, gate);
      if (message != null) _showMessage(message);
      return;
    }
    final tourismSpotTitle = _displayTitle(context);
    final eggApi = _eggApi(context);
    // 로그인 상태면 acquire 라우트가 같은 id로 서버 user_eggs row까지 이미 만들므로, 로컬 row에
    // synced_at을 박아 다음 로그인 마이그레이션에서 불필요하게 재전송(→ already_done)되지 않게 함.
    final loggedIn = context.read<AuthSession>().isLoggedIn;
    setState(() => _isAcquiringEgg = true);
    try {
      if (await _eggRepository.hasAcquiredToday(_cooldownSpotId)) {
        Sfx.instance.play('egg_cooldown');
        _showMessage(l10n.alreadyAcquiredTodayMessage);
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      // 출시 임시 조치 — 반경 판정을 서버(ST_DWithin)가 아니라 여기서 로컬 캐시 좌표로 직접 함
      // (GameConfig.serverEggProximityCheck=false, Document/temp.md "게스트 전용 출시"). 서버로
      // 좌표가 가는 유일한 경로였어서, 이 판정을 클라로 내리고 acquire에 lat/lng를 안 실으면
      // 서버엔 사용자 위치정보가 전혀 안 남는다. 판정 반경은 MapConfig.eggAcquisitionRadiusMeters
      // (서버 EGG_ACQUISITION_RADIUS_METERS 미러링, "시각화 전용" 주석이었지만 이 모드에선
      // authoritative).
      if (!GameConfig.serverEggProximityCheck) {
        final distanceToSpot = const Distance().as(
          LengthUnit.Meter,
          LatLng(position.latitude, position.longitude),
          widget.spot.position,
        );
        if (distanceToSpot > MapConfig.eggAcquisitionRadiusMeters) {
          Sfx.instance.play('egg_fail_far');
          _showMessage(l10n.locationInvalidMessage);
          return;
        }
      }

      // _cooldownSpotId(대표 spot)가 아니라 widget.spot.id(실제 탭한 spot) — 서버가 이 id로
      // 위치반경/카테고리(숙박·음식점·쇼핑 획득 불가) 판정을 하고, 쿨타임 정규화는 서버가 그
      // spot의 representative_spot_id를 보고 알아서 함(route.ts 주석 참고). 여기서 대표 id를
      // 보내면, 좌표 중복 리스트의 자식 spot(예: 관광지)을 열었는데 그 그룹의 대표가 하필
      // 숙박/음식점/쇼핑이면 실제로는 획득 가능한 카테고리인데도 서버가 대표 기준으로 판정해서
      // "숙박, 음식점, 쇼핑은 알을 획득할 수 없습니다" 오류가 잘못 뜸(2026-08-26, 사용자 리포트로
      // 발견 — 버튼은 widget.spot.contentTypeId로 정상 활성화돼 있었는데 서버 응답만 틀렸음).
      final result = await eggApi.acquireEgg(
        tourismSpotId: widget.spot.id,
        lat: GameConfig.serverEggProximityCheck ? position.latitude : null,
        lng: GameConfig.serverEggProximityCheck ? position.longitude : null,
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
        targetDistanceMeters: result.targetDistanceMeters,
        syncedAt: loggedIn ? DateTime.now() : null,
      );

      if (!mounted) return;
      Sfx.instance.play('egg_get');
      _showMessage(
        l10n.eggAcquiredMessage(
          result.name,
          rarityLabel(context, result.rarity),
        ),
      );
    } on EggLocationInvalidException {
      // 판정 반경은 서버 설정값(game-config.ts의 EGG_ACQUISITION_RADIUS_METERS)에만 있음 —
      // 클라이언트에 중복 하드코딩 안 함.
      Sfx.instance.play('egg_fail_far');
      _showMessage(l10n.locationInvalidMessage);
    } on EggSpotNotFoundException {
      Sfx.instance.play('error_generic');
      _showMessage(l10n.spotNotFoundMessage);
    } on EggCooldownException {
      // 정상 플레이에선 위 hasAcquiredToday 프리체크가 먼저 막아서 거의 안 타는 경로 — 서버
      // 쿨타임(로그인 상태 전용)이 클라이언트 프리체크를 우회한 요청을 걸러낸 경우.
      Sfx.instance.play('egg_cooldown');
      _showMessage(l10n.alreadyAcquiredTodayMessage);
    } on EggAcquisitionDisabledException {
      // 정상 플레이에선 버튼이 이미 비활성화돼 있어(canAcquireEgg) 거의 안 타는 경로.
      _showMessage(l10n.eggAcquisitionDisabledMessage);
    } on LocationServiceDisabledException {
      // 게이트 통과 후 getCurrentPosition() 사이에 위치 서비스를 끈 드문 경우.
      _showMessage(l10n.locationServiceDisabledMessage);
    } on PermissionDeniedException {
      // 게이트 통과 후 권한을 회수한 드문 경우.
      _showMessage(l10n.locationPermissionDeniedMessage);
    } catch (e) {
      Sfx.instance.play('egg_fail_network');
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
    final preloaded = members.spots
        .where((s) => s.contentTypeId == contentTypeId)
        .toList();
    Sfx.instance.play('ui_sheet_open');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // DuplicateSpotsSheet가 내부에서 SketchTheme으로 다시 감싸지만, 시트의 Material 배경은
      // 이 호출부 context의 앙비언트 테마(앱 전역 다크)로 만들어지므로 종이색을 명시(map_screen.dart
      // _onSpotTapped와 같은 이유 — 안 주면 리스트/상세가 검은 배경으로 뜸).
      backgroundColor: SketchTheme.paper,
      builder: (context) => DuplicateSpotsSheet(
        representativeId: widget.spot.id,
        contentTypeId: contentTypeId,
        preloadedSpots: preloaded.isNotEmpty ? preloaded : null,
      ),
    ).whenComplete(() => Sfx.instance.play('ui_sheet_close'));
  }

  // 상세 정보의 홈페이지 필드는 순수 텍스트(가끔 HTML 앵커 태그가 그대로 섞여 오기도 함, TourAPI
  // 원본 데이터 특성)라 href만 뽑아서 열어야 함 — 못 찾으면 문자열 자체를 URL로 시도(실기기 확인,
  // Document/temp.md 참고: 지금까지는 탭해도 아예 반응이 없었음).
  Future<void> _openHomepage(String homepage) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final hrefMatch = RegExp('href="([^"]+)"').firstMatch(homepage);
    final url = hrefMatch?.group(1) ?? homepage.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unlinkLaunchFailedMessage(''))),
      );
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.unlinkLaunchFailedMessage(''))),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.unlinkLaunchFailedMessage('$e'))),
      );
    }
  }

  // homepage 필드 표시용 — <a href="...">라벨</a> 형태로 오면 태그를 걷어내고 안의 라벨(보통 URL
  // 자체)만 남김. _openHomepage()는 클릭 시 이동할 href 값을 뽑아야 하니 원본 문자열을 그대로 씀.
  String _stripHtmlTags(String raw) =>
      raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  void _openImageViewer(List<TourismSpotImage> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _ImageViewerScreen(images: images, initialIndex: initialIndex),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spot = widget.spot;
    final displayTitle = _displayTitle(context);
    // 지도 화면과 같은 그림책+연필 스케치 테마를 이 바텀시트에만 지역 적용(2026-08-26, 사용자
    // 요청) — showModalBottomSheet는 Overlay에 별도로 끼워지는 라우트라 지도 화면의 Theme
    // 오버라이드를 자동 상속하지 않음(config/sketch/sketch_theme.dart 주석 참고), 그래서 여기서
    // 다시 감싸야 함. 시트 바깥 배경(Material)은 map_screen.dart의 showModalBottomSheet 호출부에서
    // backgroundColor로 맞춤. Builder로 새 context를 얻어야 함 — 아래 Theme.of(context) 호출들이
    // 이 Theme 바깥의 앱 전역 테마를 잡지 않도록(dex_detail_screen.dart와 같은 이유).
    //
    // Material로 한 번 더 감싸야 함 — Scaffold가 없는 시트라 이 서브트리 안에는 새 DefaultTextStyle을
    // 세워줄 위젯이 없고, style을 안 준 Text(예: 아래 detail.overview)는 이 시트를 띄운
    // showModalBottomSheet가 호출 시점(지도 화면의 Theme 오버라이드보다 상위)의 앙비언트 테마로 이미
    // 세워둔 DefaultTextStyle을 그대로 물려받아 다크 테마용 옅은 색으로 나왔음(실기기 확인, 2026-08-26
    // — "더보기" 설명 텍스트가 크림 배경 위에서 거의 안 보이는 문제).
    return Theme(
      data: SketchTheme.themeData,
      child: Builder(
        builder: (context) => Material(
          color: Colors.transparent,
          child: SafeArea(
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
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    displayTitle,
                    // 관광지 이름/주소/설명은 실제 고유명사·행정구역명이라 손글씨 폰트(Gaegu)보다
                    // 가독성이 중요해서 원래의 기본 서체(Roboto)로 되돌림(2026-08-26, 사용자 요청 —
                    // dex_detail_screen.dart의 몬스터 설명과 같은 이유).
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontFamily: 'Roboto'),
                  ),
                  if (spot.addr1 != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        spot.addr1,
                        spot.addr2,
                      ].where((e) => e != null && e.isNotEmpty).join(' '),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontFamily: 'Roboto'),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text(
                            l10n.duplicateSpotsLoadFailedMessage(
                              '${snapshot.error}',
                            ),
                          );
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
                                onTap: () =>
                                    _openCategory(members, entry.contentTypeId),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  // 'More'/'Less'(더보기/접기 토글)와 'Get egg'를 한 줄에 배치 — spaceBetween으로
                  // Get egg는 항상 이 줄의 오른쪽 끝에 고정. 더보기 버튼은 상세를 펼쳐도 사라지지
                  // 않고 '접기'로 바뀌어, 끝까지 펼친 뒤에도 다시 접을 수 있음.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _toggleDetail,
                        child: Text(
                          _detailExpanded
                              ? l10n.showLessButton
                              : l10n.showMoreButton,
                        ),
                      ),
                      SketchButton(
                        onPressed:
                            (!canAcquireEgg(spot.contentTypeId) ||
                                _isAcquiringEgg)
                            ? null
                            : _onAcquireEggPressed,
                        leading: _isAcquiringEgg
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SketchTheme.paper,
                                ),
                              )
                            : const Icon(
                                Icons.egg_outlined,
                                color: SketchTheme.paper,
                                size: 18,
                              ),
                        // 획득 불가 구역(숙박/음식점/쇼핑)에서는 버튼 자체가 비활성(회색조)돼서
                        // 눈에 잘 안 띄는 데다, 라벨이 여전히 "알 획득하기"라 왜 안 눌리는지
                        // 헷갈리기 쉬움(2026-08-26, 사용자 피드백) — 이 상황엔 라벨로 이유를
                        // 바로 알려줌.
                        label: canAcquireEgg(spot.contentTypeId)
                            ? l10n.acquireEggButton
                            : l10n.acquireEggDisabledButton,
                      ),
                    ],
                  ),
                  if (!canAcquireEgg(spot.contentTypeId)) ...[
                    const SizedBox(height: 8),
                    // 기본 bodySmall(작고 옅은 보조 텍스트 톤)이 잘 안 보인다는 피드백(2026-08-26)
                    // — 경고 아이콘을 붙이고 bodyMedium 굵게로 존재감을 키움.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: SketchTheme.ink,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.eggAcquisitionDisabledMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_eggResultMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _eggResultMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (_detailExpanded && _detailFuture != null) ...[
                    const SizedBox(height: 12),
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
                          return Text(
                            l10n.detailLoadFailedMessage('${snapshot.error}'),
                          );
                        }
                        final detail = snapshot.data!;
                        // 영어 화면인데 매칭된 영문 원문이 없어 서버가 국문으로 폴백한 경우 —
                        // 아무 표시 없이 한국어만 나오면 오역처럼 보이므로 그 사실을 먼저 안내(실기기
                        // 확인, Document/temp.md 참고).
                        final showNoEnglishNotice =
                            apiLocaleOf(context) == 'en' && !detail.usedEnglish;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showNoEnglishNotice) ...[
                              Text(
                                l10n.noEnglishTranslationLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (detail.overview != null)
                              Text(
                                detail.overview!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontFamily: 'Roboto',
                                      height: 1.5,
                                    ),
                              ),
                            if (detail.homepage != null &&
                                detail.homepage!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _openHomepage(detail.homepage!),
                                child: Text(
                                  // 원본 필드에 <a href="...">...</a> 같은 HTML 앵커 태그가 그대로
                                  // 섞여 오는 경우가 있어(_openHomepage 주석 참고) 태그를 걷어내고
                                  // 순수 텍스트만 표시(2026-08-26, 사용자 요청 — 예전엔 href="..."가
                                  // 그대로 화면에 보였음). 실제 이동 대상(_openHomepage)은 원본
                                  // detail.homepage를 그대로 씀 — href 속성값을 잃지 않기 위함.
                                  _stripHtmlTags(detail.homepage!),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
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
                                      child: GestureDetector(
                                        onTap: () => _openImageViewer(
                                          detail.images,
                                          index,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: image.smallImageUrl,
                                            width: 100,
                                            height: 100,
                                            fit: image.allowsCrop
                                                ? BoxFit.cover
                                                : BoxFit.contain,
                                            memCacheWidth: 200,
                                            errorWidget: (
                                              context,
                                              url,
                                              error,
                                            ) => const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            // 이 상세(overview·홈페이지·이미지)는 전부 한국관광공사 TourAPI
                            // (detailCommon2/detailImage2 프록시) 응답이라, 공공누리 제1유형
                            // 출처표시 조건에 맞춰 데이터가 실제로 노출되는 이 지점 바로 아래에
                            // 출처를 표기함. 전체 문구/라이선스는 마이페이지 → "데이터 출처 및
                            // 라이선스"(서버 /credits 페이지).
                            const SizedBox(height: 12),
                            Text(
                              l10n.tourApiAttribution,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontFamily: 'Roboto',
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
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
          // 2026-08-26, 사용자 요청 — 자동 생성 색(surfaceContainerHighest)이 크림 배경과 잘
          // 안 어울려서 SketchTheme의 종이 톤으로 고정. 재사용처인 duplicate_spots_sheet.dart도
          // 이제 SketchTheme을 입혀서(2026-08-31) 두 화면에서 같은 톤으로 보임.
          color: SketchTheme.paperDark,
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

/// 상세 사진 탭 시 여는 전체화면 확대 뷰어 — 실기기 확인 결과 썸네일을 탭해도 확대가 안 됐던 문제
/// (Document/temp.md 참고) 대응. 원본 화질(originImgUrl)로 보여주고, 여러 장이면 좌우로 넘겨볼 수
/// 있게 PageView로 감쌈. 확대/축소는 별도 패키지 없이 Flutter 기본 InteractiveViewer로 충분.
class _ImageViewerScreen extends StatelessWidget {
  final List<TourismSpotImage> images;
  final int initialIndex;

  const _ImageViewerScreen({required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 확대해 보는 원본 사진도 TourAPI(detailImage2) 제공분이라 여기에도 출처를 표기.
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(
          top: false,
          child: Text(
            l10n.tourApiAttribution,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: images[index].originImgUrl,
                fit: BoxFit.contain,
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
