import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/app_settings_repository.dart';

/// 효과음 재생기 — `Document/sound_effect_plan.md` 구현.
///
/// - 사건음(`egg_get`/`dex_new_entry`/`welcome_*`)은 1개 고정, 고빈도 UI음
///   (`ui_tap` ×4, `ui_sheet_*` ×2)은 셔플백으로 변주 — 순수 랜덤은 같은 게 연속으로 나와서 안 씀.
/// - [_aliases]: 별도 파일 없이 기존 음을 재사용(재사용 맵). 예: `error_generic` → `egg_fail_far`.
/// - `sfx_enabled`(app_settings, 기본 on)가 `'false'`면 전부 무음. 마이페이지 `_SoundCard`가 토글.
/// - [startCrackLoop]/[stopCrackLoop]: 부화 흔들림 구간 동안 `hatch_crack`을 루프.
/// - 재생 실패는 절대 UI로 전파하지 않음 — 전부 try/catch, fire-and-forget.
///
/// ## 재생 방식 (2026-09-09 재작성)
///
/// **파일마다 전용 저지연 플레이어 하나**([_players], `PlayerMode.lowLatency` = Android SoundPool).
/// 이전엔 `AudioPlayer` 4개를 라운드로빈으로 20여 개 파일에 돌려썼는데, 기본 `MediaPlayer` 모드는
/// 매 재생마다 `stop → setDataSource → prepareAsync(비동기) → start`라, 같은 플레이어가 재사용될 때
/// 이전 소리의 prepare가 안 끝났으면 그 소리가 잘리거나(안 들림) 어정쩡하게 시작됨(눌린 소리).
/// SoundPool은 샘플을 미리 로드해두고 `resume()` 한 번에 즉시 재생 + 최대 32스트림 자동 믹싱이라
/// 이 문제가 없음. 피치 지터(`setPlaybackRate`)도 상태 전이를 하나 더 얹어 불안정하게 만들어서 제거
/// (변주는 셔플백만으로 충분).
class Sfx {
  Sfx._();

  static final Sfx instance = Sfx._();

  static const _enabledKey = 'sfx_enabled';
  static const _dir = 'audio';

  final _settings = const AppSettingsRepository();
  final _rng = Random();

  /// 파일명 → 그 파일 전용 저지연 플레이어.
  final Map<String, AudioPlayer> _players = {};
  AudioPlayer? _loopPlayer;

  final Map<String, List<int>> _bags = {};
  final Map<String, int> _lastIndex = {};

  Timer? _crackFadeTimer;

  bool _enabled = true;
  bool _ready = false;

  bool get enabled => _enabled;

  /// id → `assets/audio/` 파일명. 길이 2 이상이면 변주(셔플백).
  static const Map<String, List<String>> _clips = {
    // 공통 UI
    'ui_tap': ['ui_tap_1.ogg', 'ui_tap_2.ogg', 'ui_tap_3.ogg', 'ui_tap_4.ogg'],
    'ui_sheet_open': ['ui_sheet_open_1.ogg', 'ui_sheet_open_2.ogg'],
    'ui_sheet_close': ['ui_sheet_close_1.ogg', 'ui_sheet_close_2.ogg'],
    'ui_confirm': ['ui_confirm.ogg'],
    // 알 획득
    'egg_get': ['egg_get.ogg'],
    'egg_fail_far': ['egg_fail_far.ogg'],
    // egg_cooldown 은 egg_fail_far 재사용(_aliases) — 2026-09-08 결정
    // 부화 (흔들림 = hatch_crack 루프, 리빌 전용 효과음 없음 — 2026-09-09)
    'hatch_ready': ['hatch_ready.ogg'],
    // 도감
    'dex_new_entry': ['dex_new_entry.ogg'],
    'dex_open_detail': ['dex_open_detail.ogg'],
    'dex_locked': ['alert_warning.ogg'],
    // 알 보관함 / 파트너
    'partner_set': ['partner_set.ogg'],
    'partner_full': ['alert_warning.ogg'],
    // 온보딩 / 웰컴
    'welcome_gift': ['welcome_gift.ogg'],
    'welcome_egg_receive': ['welcome_egg_receive.ogg'],
  };

  /// 흔들림 루프 전용(one-shot 풀에 안 넣음).
  static const _loopFile = 'hatch_crack.ogg';

  /// 별도 파일 없이 기존 음을 재사용(sound_effect_plan.md 재사용 맵).
  static const Map<String, String> _aliases = {
    'egg_fail_network': 'egg_fail_far',
    'error_generic': 'egg_fail_far',
    'egg_cooldown': 'egg_fail_far',
    'notif_hatch_ready': 'hatch_ready',
  };

  // 카테고리별 상대 게인(sound_effect_plan.md 2장) — 요청 id(별칭 해석 전) 기준.
  static const _uiGain = 0.45;
  static const _feedbackGain = 0.8;
  static const _eventGain = 1.0;

  static const Set<String> _uiIds = {
    'ui_tap', 'ui_sheet_open', 'ui_sheet_close', 'ui_toggle',
    'dex_open_detail', 'dex_locked', 'onboarding_step',
  };
  static const Set<String> _feedbackIds = {
    'ui_confirm', 'egg_fail_far', 'egg_fail_network', 'egg_cooldown',
    'error_generic', 'partner_set', 'partner_full', 'hatch_ready',
    'offline_banner',
  };

  double _gainFor(String id) {
    if (_uiIds.contains(id)) return _uiGain;
    if (_feedbackIds.contains(id)) return _feedbackGain;
    return _eventGain; // egg_get, dex_new_entry, welcome_*
  }

  /// `main()`에서 1회 호출. 실패해도 앱은 그대로 진행(무음).
  Future<void> init() async {
    try {
      _enabled = (await _settings.getValue(_enabledKey)) != 'false';

      // 산책 중 사용자 음악을 끊지 않도록 focus는 mixWithOthers(Android는 오디오 포커스를
      // 잡지 않음, iOS는 mixWithOthers 옵션). respectSilence=false → Android media usage 유지.
      // iOS 무음 스위치까지 존중하려면 배포 시 AudioContext를 직접 구성(audioplayers FAQ).
      // 플레이어 생성 전에 불러야 이후 만들어지는 플레이어가 이 컨텍스트를 물려받아 SoundPool을
      // 하나만 공유함.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );

      final files = <String>{for (final list in _clips.values) ...list};
      // 에셋을 미리 임시파일로 풀어둠 — 각 플레이어의 setSource가 이걸 재사용(IO 절약).
      await AudioCache.instance.loadAll([
        for (final f in files) '$_dir/$f',
        '$_dir/$_loopFile',
      ]);

      // 파일당 저지연 플레이어 하나 + 소스 프리로드(SoundPool.load).
      await Future.wait(
        files.map((f) async {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('$_dir/$f'));
          _players[f] = p;
        }),
      );

      // 루프 재생은 심리스가 중요해서 MediaPlayer + ReleaseMode.loop 유지(SoundPool 루프는
      // 필요 시 전환 검토).
      final loop = AudioPlayer();
      await loop.setReleaseMode(ReleaseMode.loop);
      _loopPlayer = loop;

      _ready = true;
    } catch (e) {
      debugPrint('Sfx.init 실패(무음으로 진행): $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) stopCrackLoop();
    try {
      await _settings.setValue(_enabledKey, value ? 'true' : 'false');
    } catch (e) {
      debugPrint('Sfx.setEnabled 저장 실패: $e');
    }
  }

  /// 효과음 1회. fire-and-forget — 반환을 기다릴 필요 없음.
  void play(String id, {double volumeScale = 1.0}) {
    if (!_enabled || !_ready) return;
    final fileId = _aliases[id] ?? id;
    final clips = _clips[fileId];
    if (clips == null) {
      assert(false, 'Sfx: 알 수 없는 id "$id"');
      return;
    }
    final player = _players[_pick(fileId, clips)];
    if (player == null) return;
    final volume = (_gainFor(id) * volumeScale).clamp(0.0, 1.0);
    unawaited(_fire(player, volume));
  }

  Future<void> _fire(AudioPlayer p, double volume) async {
    try {
      // 저지연(SoundPool): stop()이 이전 streamId를 비워야 다음 resume()이 새 스트림을 만든다
      // (안 하면 두 번째 재생부터 무음). setVolume은 스트림이 없을 땐 값만 저장해두고,
      // resume()→SoundPool.play가 그 값으로 재생한다.
      await p.stop();
      await p.setVolume(volume);
      await p.resume();
    } catch (e) {
      debugPrint('Sfx.play 실패: $e');
    }
  }

  /// 셔플백: 변주를 섞어 순서대로 소진, 리필 시 직전 인덱스가 다음에 바로 나오면 회전.
  String _pick(String id, List<String> clips) {
    if (clips.length == 1) return clips.first;
    var bag = _bags[id];
    if (bag == null || bag.isEmpty) {
      bag = List<int>.generate(clips.length, (i) => i)..shuffle(_rng);
      final last = _lastIndex[id];
      if (last != null && bag.last == last) {
        bag.insert(0, bag.removeLast());
      }
      _bags[id] = bag;
    }
    final idx = bag.removeLast();
    _lastIndex[id] = idx;
    return clips[idx];
  }

  /// 부화 흔들림 구간 시작 — [stopCrackLoop]까지 `hatch_crack`을 루프.
  void startCrackLoop() {
    if (!_enabled || !_ready) return;
    final p = _loopPlayer;
    if (p == null) return;
    _crackFadeTimer?.cancel();
    _crackFadeTimer = null;
    unawaited(
      () async {
        try {
          await p.stop();
          await p.setVolume(_eventGain);
          await p.play(AssetSource('$_dir/$_loopFile'), volume: _eventGain);
        } catch (e) {
          debugPrint('Sfx.startCrackLoop 실패: $e');
        }
      }(),
    );
  }

  /// [fade]=true면 ~350ms에 걸쳐 볼륨을 잦아들게 한 뒤 정지(리빌 순간 크랙이 뚝 끊기지 않게).
  /// 화면이 사라지는 등 즉시 멈춰야 할 땐 false.
  void stopCrackLoop({bool fade = false}) {
    final p = _loopPlayer;
    if (p == null) return;
    _crackFadeTimer?.cancel();
    _crackFadeTimer = null;
    if (!fade) {
      unawaited(p.stop().catchError((Object _) {}));
      return;
    }
    const steps = 7;
    var remaining = steps;
    _crackFadeTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      remaining--;
      if (remaining <= 0) {
        t.cancel();
        _crackFadeTimer = null;
        unawaited(p.stop().catchError((Object _) {}));
        return;
      }
      unawaited(
        p.setVolume(_eventGain * remaining / steps).catchError((Object _) {}),
      );
    });
  }
}
