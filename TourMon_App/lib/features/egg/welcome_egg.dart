import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/app_settings_repository.dart';
import '../../l10n/api_locale.dart';
import '../auth/auth_session.dart';
import '../auth/authorized_api_client.dart';
import 'egg_api.dart';
import 'egg_repository.dart';
import 'user_egg.dart';

/// "이 기기에서 웰컴 알을 이미 받았다"는 로컬 플래그(값은 지급 시각 ISO8601). onboarding_screen의
/// `onboarding_seen_version`과 같은 app_settings key-value 패턴.
const _welcomeEggClaimedKey = 'welcome_egg_claimed';

/// 앱 최초 실행 시(정확히는 "이 기기에서 아직 웰컴 알을 안 받았으면") common 알 1개를 지급한다.
/// `map_screen`이 온보딩 캐러셀을 닫은 직후 호출하고, 반환된 알로 "선물이 왔어요" 다이얼로그를
/// 띄운다(`welcome_gift_dialog.dart`).
///
/// - **기존 설치분도 대상** — 플래그가 없으면 다음 실행에서 받는다(2026-09-01 사용자 결정). 신규
///   설치만 주려면 마이그레이션에서 기존 기기에 플래그를 미리 박아야 하지만, 재참여 유도 목적상
///   기존 유저에게도 주기로 함.
/// - **재설치 파밍 허용** — 게스트는 서버 신원이 없어 새 설치/재설치를 구분 못 한다. 낮은 등급
///   1개 + 부화에 거리 필요 + 서버 `egg_vouchers` 90일 TTL이 상한이라 감수(Document/temp.md).
/// - 서버가 발급하는 `egg_vouchers` 기반이라 스팟에서 받은 일반 게스트 알과 구조적으로 동일 —
///   게스트→회원 마이그레이션/부화 경로에 특수 처리가 없다(Document/temp.md "앱 설치 웰컴 알").
///
/// 반환: 방금 지급된 [UserEgg]. 이미 받았거나(플래그 존재) 네트워크 실패면 null — 실패 시
/// 플래그를 남기지 않아 다음 실행에서 자연히 재시도된다("선물이 왔어요" 팝업도 이때는 안 뜸).
Future<UserEgg?> claimWelcomeEggIfNeeded(BuildContext context) async {
  const settings = AppSettingsRepository();
  if (await settings.getValue(_welcomeEggClaimedKey) != null) return null;
  if (!context.mounted) return null;

  final session = context.read<AuthSession>();
  final api = EggApi(AuthorizedApiClient(session, locale: apiLocaleOf(context)));
  try {
    final result = await api.claimWelcomeEgg();
    final egg = await const EggRepository().insertEgg(
      overrideId: result.id,
      tourismSpotId: null,
      tourismSpotTitle: null,
      // 스팟이 없으니 content_type도 없음 — 부화 시 몬스터 결정이 전체 종 균등 가중치로 폴백한다
      // (monster_determination.dart / 서버 monster-determination.ts 동일 규칙, 마이그레이션 위조
      // 검사 possibleMonsterSpeciesIds도 같은 폴백을 봄).
      contentTypeId: null,
      eggTypeId: result.eggTypeId,
      rarity: result.rarity,
      name: result.name,
      description: result.description,
      targetDistanceMeters: result.targetDistanceMeters,
      // 웰컴 라우트는 acquire와 달리 로그인 상태여도 user_eggs row를 만들지 않고 voucher만 발급하므로
      // 항상 미동기화(synced_at NULL)로 둔다 — 로그인 유저면 곧이어 migrateIfNeeded가 흡수한다.
      syncedAt: null,
    );
    await settings.setValue(
      _welcomeEggClaimedKey,
      DateTime.now().toIso8601String(),
    );
    return egg;
  } catch (e) {
    developer.log('웰컴 알 지급 실패(다음 실행 재시도): $e', name: 'WelcomeEgg');
    return null;
  }
}
