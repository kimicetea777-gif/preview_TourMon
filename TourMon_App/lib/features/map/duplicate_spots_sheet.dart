import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/sketch/sketch_theme.dart';
import '../../data/tourism_spot_repository.dart';
import '../../l10n/api_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import 'tourism_spot.dart';
import 'tourism_spot_sheet.dart';

/// 좌표 중복(같은 건물 내 여러 매장) 리스트 — 카테고리 아이콘(tourism_spot_sheet.dart의
/// CategoryIconTile)을 탭하면 그 카테고리 하나로 필터링된 스팟 목록을 보여줌. 카테고리 "선택"
/// 자체는 마커 시트에서 이미 끝난 상태로 열리므로, 여기서는 고르는 화면 없이 곧장 리스트만 표시.
class DuplicateSpotsSheet extends StatefulWidget {
  final int representativeId;
  final int contentTypeId;
  // 호출부(TourismSpotSheet)가 이미 전체 spots를 갖고 있으면(항목 수가 임계치 이하라 서버가 한
  // 번에 다 내려준 경우) 넘겨받아 그대로 씀 — 없으면 여기서 contentTypeId로 다시 조회함.
  final List<TourismSpot>? preloadedSpots;

  const DuplicateSpotsSheet({
    super.key,
    required this.representativeId,
    required this.contentTypeId,
    this.preloadedSpots,
  });

  @override
  State<DuplicateSpotsSheet> createState() => _DuplicateSpotsSheetState();
}

class _DuplicateSpotsSheetState extends State<DuplicateSpotsSheet> {
  final _tourismSpotRepository = const TourismSpotRepository();
  late final Future<List<TourismSpot>> _future;

  @override
  void initState() {
    super.initState();
    final preloaded = widget.preloadedSpots;
    _future = preloaded != null
        ? Future.value(preloaded)
        : _tourismSpotRepository
            .getMembers(widget.representativeId, contentTypeId: widget.contentTypeId)
            .then((members) => members.spots);
  }

  // cooldownSpotId를 대표 spot으로 명시 — 안 넘기면 TourismSpotSheet가 이 자식 spot의 원본 id로
  // 로컬 쿨타임을 체크/저장해버려서, 게스트 모드(서버 검증 없음)에서 리스트 항목을 갈아타며 하루에
  // 여러 번 알을 받는 어뷰징이 가능해짐(later.md/temp.md "관광지 마커 — 좌표 중복" 참고).
  void _openSpot(TourismSpot spot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // TourismSpotSheet 자체가 SketchTheme으로 다시 감싸지만, 시트의 Material 배경은
      // showModalBottomSheet 호출부 context의 앙비언트 테마(=앱 전역 다크)로 만들어지므로
      // 명시적으로 종이색을 줌(map_screen.dart _onSpotTapped와 같은 이유).
      backgroundColor: SketchTheme.paper,
      builder: (context) => TourismSpotSheet(
        spot: spot,
        cooldownSpotId: widget.representativeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 지도 화면과 같은 그림책+연필 스케치 테마를 이 시트에도 지역 적용 — showModalBottomSheet는
    // Overlay에 별도로 끼워지는 라우트라 호출부(TourismSpotSheet)의 Theme 오버라이드를 자동
    // 상속하지 않음(tourism_spot_sheet.dart build() 주석 참고). 시트 바깥 Material 배경은 이
    // 시트를 여는 showModalBottomSheet 호출부(tourism_spot_sheet.dart _openCategory)의
    // backgroundColor로 맞춤. Builder로 새 context를 얻어 아래 Theme.of(context)가 이 테마를 잡게 함.
    return Theme(
      data: SketchTheme.themeData,
      child: Builder(
        builder: (context) => Material(
          color: Colors.transparent,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(contentTypeIcon(widget.contentTypeId)),
                        const SizedBox(width: 8),
                        Text(
                          contentTypeLabel(context, widget.contentTypeId),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<TourismSpot>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              l10n.duplicateSpotsLoadFailedMessage(
                                '${snapshot.error}',
                              ),
                            ),
                          );
                        }
                        return _SpotList(
                          spots: snapshot.data!,
                          onTap: _openSpot,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotList extends StatelessWidget {
  final List<TourismSpot> spots;
  final ValueChanged<TourismSpot> onTap;

  const _SpotList({required this.spots, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return ListTile(
          leading: spot.firstImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: spot.firstImage!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                )
              : const SizedBox(width: 48, height: 48),
          // 관광지 이름/주소는 고유명사·행정구역명이라 손글씨 폰트(Gaegu)보다 가독성이 중요해서
          // 기본 서체(Roboto)로 표시 — tourism_spot_sheet.dart의 제목/주소와 같은 이유.
          title: Text(
            displayTitleOf(context, title: spot.title, titleEn: spot.titleEn),
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontFamily: 'Roboto'),
          ),
          subtitle: spot.addr1 != null
              ? Text(
                  [spot.addr1, spot.addr2].where((e) => e != null && e.isNotEmpty).join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontFamily: 'Roboto'),
                )
              : null,
          onTap: () => onTap(spot),
        );
      },
    );
  }
}
