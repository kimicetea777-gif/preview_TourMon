import 'package:flutter/material.dart';

import '../../config/sketch/sketch_button.dart';
import '../../config/sketch/sketch_card.dart';
import '../../config/sketch/sketch_theme.dart';
import '../../data/app_settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../egg/egg_image.dart';

const _onboardingVersionKey = 'onboarding_seen_version';

/// 인트로 문구/구성이 크게 바뀌면 이 값을 올려서 저장된 버전과 달라지게 함 — 그러면 기존
/// 사용자에게도 다시 한 번 보여줌(location_consent_dialog.dart의 `_currentConsentVersion`과 같은
/// 방식).
const _currentOnboardingVersion = '1';

/// 앱 최초 실행 시(아직 현재 버전 인트로를 본 적 없으면) 핵심 루프
/// (마커에서 알 획득 → 파트너 등록 → 걸어서 거리 적립 → 부화)를 4장짜리 전체화면 캐러셀로
/// 한 번 보여준다. `MapScreen`이 첫 프레임 직후 호출 — 지도는 뒤에서 로딩되고, 사용자가 인트로를
/// 닫으면 그대로 지도가 보인다. 위치/신체 활동 권한 다이얼로그는 이 인트로가 대체하지 않고
/// 각자 필요한 시점에 그대로 뜬다(just-in-time).
Future<void> showOnboardingIfNeeded(BuildContext context) async {
  const settings = AppSettingsRepository();
  final stored = await settings.getValue(_onboardingVersionKey);
  if (stored == _currentOnboardingVersion) return;
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
}

/// 마이페이지 "앱 사용법 다시 보기"에서 다시 열 때는 [replay]를 true로 — 이때는 마지막 장의
/// 버튼이 "시작하기" 대신 "닫기"로 바뀐다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // 스킵이든 끝까지 봤든 "현재 버전 인트로를 봤다"고 기록 — 다시 보기(replay)로 연 경우에도
    // 기록해두면 그만이라 분기하지 않음.
    await const AppSettingsRepository().setValue(
      _onboardingVersionKey,
      _currentOnboardingVersion,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _next(int lastIndex) {
    if (_index >= lastIndex) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pages = <_OnboardingPageData>[
      _OnboardingPageData(
        illustration: const _SpotIllustration(),
        title: l10n.onboardingSpotTitle,
        body: l10n.onboardingSpotBody,
      ),
      _OnboardingPageData(
        illustration: const _PartnerIllustration(),
        title: l10n.onboardingPartnerTitle,
        body: l10n.onboardingPartnerBody,
      ),
      _OnboardingPageData(
        illustration: const _WalkIllustration(),
        title: l10n.onboardingWalkTitle,
        body: l10n.onboardingWalkBody,
      ),
      _OnboardingPageData(
        illustration: const _HatchIllustration(),
        title: l10n.onboardingHatchTitle,
        body: l10n.onboardingHatchBody,
      ),
    ];
    final lastIndex = pages.length - 1;
    final onLast = _index == lastIndex;

    return Theme(
      data: SketchTheme.themeData,
      child: Scaffold(
        backgroundColor: SketchTheme.paper,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.onboardingSkipButton),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) =>
                      _OnboardingPageView(data: pages[i]),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    _Dot(active: i == _index),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SketchButton(
                  onPressed: () => _next(lastIndex),
                  label: onLast
                      ? (widget.replay
                            ? l10n.onboardingCloseButton
                            : l10n.onboardingStartButton)
                      : l10n.onboardingNextButton,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final Widget illustration;
  final String title;
  final String body;
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(height: 200, child: Center(child: data.illustration)),
          const Spacer(flex: 1),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? SketchTheme.accent
            : SketchTheme.ink.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// --- 일러스트 (신규 아트 없이 기존 에셋 + 머티리얼 아이콘 조합) ---

/// 1장 — 관광지 마커에서 알 획득. 실제 지도에 쓰는 카테고리 마커 PNG 몇 개를 스케치 카드 위에
/// 흩어 놓고, 한 마커 위에 알을 얹어 "마커 = 알" 이라는 걸 보여줌.
class _SpotIllustration extends StatelessWidget {
  const _SpotIllustration();

  @override
  Widget build(BuildContext context) {
    return SketchCard(
      seed: 3,
      rotationDegrees: -1.5,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 180,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              left: 4,
              top: 8,
              child: _Marker('assets/markers/cultural.png'),
            ),
            const Positioned(
              right: 0,
              bottom: 4,
              child: _Marker('assets/markers/festival.png'),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EggImage(rarity: 'common', width: 56),
                const SizedBox(height: 2),
                Image.asset('assets/markers/tourist.png', width: 44),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: 0.55, child: Image.asset(asset, width: 34));
  }
}

/// 2장 — 알 보관함에서 파트너 알 등록. 실제 파트너 토글에 쓰는 체크 아이콘(SketchTheme.accent)을
/// 알 오른쪽 아래에 얹어 알 보관함 UI와 같은 시각 언어를 씀.
class _PartnerIllustration extends StatelessWidget {
  const _PartnerIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const EggImage(rarity: 'rare', width: 130),
        const Positioned(
          right: -6,
          bottom: 4,
          child: Icon(Icons.check_circle, size: 44, color: SketchTheme.accent),
        ),
      ],
    );
  }
}

/// 3장 — 걸어서 거리 적립. 걷는 사람 + 알 + 진행바로 "걸으면 알이 자란다"를 표현.
class _WalkIllustration extends StatelessWidget {
  const _WalkIllustration();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_walk, size: 88, color: SketchTheme.ink),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 28, color: SketchTheme.ink),
            const SizedBox(width: 8),
            const EggImage(rarity: 'epic', width: 72),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(value: 0.6, minHeight: 8),
          ),
        ),
      ],
    );
  }
}

/// 4장 — 부화. 앱에 몬스터 아트가 번들돼 있지 않아(원격 이미지 서버) 알 + 반짝임 아이콘으로
/// "부화" 순간을 표현.
class _HatchIllustration extends StatelessWidget {
  const _HatchIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const EggImage(rarity: 'legendary', width: 130),
        const Positioned(
          top: -8,
          right: 8,
          child: Icon(Icons.auto_awesome, size: 34, color: SketchTheme.accent),
        ),
        const Positioned(
          bottom: 4,
          left: -4,
          child: Icon(
            Icons.auto_awesome,
            size: 22,
            color: SketchTheme.accentBlue,
          ),
        ),
      ],
    );
  }
}
