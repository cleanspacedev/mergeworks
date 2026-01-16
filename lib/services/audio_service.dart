import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class AudioService extends ChangeNotifier {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final Random _rand = Random();
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  double _musicVolume = 1.0;
  double _sfxVolume = 1.0;
  bool _isMusicPlaying = false; // track state to avoid double starts

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> initialize() async {
    try {
      // Ensure proper audio context across platforms (mobile only)
      try {
        if (!kIsWeb) {
          final ctx = AudioContext(
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.gain,
              stayAwake: false,
            ),
          );
          await AudioPlayer.global.setAudioContext(ctx);
          await _musicPlayer.setAudioContext(ctx);
        }
      } catch (e) {
        debugPrint('Failed to set audio context: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _musicVolume = (prefs.getDouble('music_volume') ?? 1.0).clamp(0.0, 1.0);
      _sfxVolume = (prefs.getDouble('sfx_volume') ?? 1.0).clamp(0.0, 1.0);
      // Prepare background music looping
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      if (_musicEnabled && !kIsWeb) {
        unawaited(_startBackgroundMusic());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load audio settings: $e');
    }
  }

  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', _soundEnabled);
    } catch (e) {
      debugPrint('Failed to save sound setting: $e');
    }
    notifyListeners();
  }

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', _musicEnabled);
    } catch (e) {
      debugPrint('Failed to save music setting: $e');
    }
    if (_musicEnabled) {
      unawaited(_startBackgroundMusic());
    } else {
      unawaited(_stopBackgroundMusic());
    }
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    _musicVolume = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('music_volume', _musicVolume);
    } catch (e) {
      debugPrint('Failed to save music volume: $e');
    }
    try {
      await _musicPlayer.setVolume(_musicVolume);
    } catch (e) {
      debugPrint('Failed to apply music volume: $e');
    }
    notifyListeners();
  }

  Future<void> setSfxVolume(double value) async {
    _sfxVolume = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('sfx_volume', _sfxVolume);
    } catch (e) {
      debugPrint('Failed to save sfx volume: $e');
    }
    notifyListeners();
  }

  // Public: call on first user gesture (enables bg music on Web and ensures start elsewhere)
  Future<void> maybeStartMusicFromUserGesture() async {
    if (!_musicEnabled) {
      debugPrint('MUSIC: Not starting (music disabled)');
      return;
    }
    if (_isMusicPlaying) {
      debugPrint('MUSIC: Already playing');
      return;
    }
    // On web we intentionally defer autoplay until a user gesture triggers this
    await _startBackgroundMusic(force: true);
  }

  // ========== Background Music ==========
  Future<void> _startBackgroundMusic({bool force = false}) async {
    try {
      if (kIsWeb && !force) return; // Defer music start on web until explicit user action
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setSource(AssetSource('audio/Music/bgmusic.wav'));
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.resume();
      _isMusicPlaying = true;
      debugPrint('MUSIC: Background music started');
    } catch (e) {
      debugPrint('Failed to start background music: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      _isMusicPlaying = false;
      debugPrint('MUSIC: Background music stopped');
    } catch (e) {
      debugPrint('Failed to stop background music: $e');
    }
  }

  // ========== SFX Helpers ==========
  Future<void> _playSfx(String assetPath, {double volume = 1.0, String? caption, double playbackRate = 1.0}) async {
    if (!_soundEnabled) return;
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        try { player.dispose(); } catch (_) {}
      });
      await player.setReleaseMode(ReleaseMode.stop);
      final effective = (volume * _sfxVolume).clamp(0.0, 1.0);
      await player.setVolume(effective);
      // Best-effort: adjust playback rate if supported by platform
      try { await player.setPlaybackRate(playbackRate); } catch (_) {}
      await player.play(AssetSource(assetPath));
      if (caption != null) {
        debugPrint('SFX: $caption');
        await _maybeAnnounce(caption);
      }
    } catch (e) {
      debugPrint('SFX play failed ($assetPath): $e');
    }
  }

  // Deterministic base playback rate per tier to create a unique sound signature
  double _rateForTier(int tier) {
    final List<int> semitoneOffsets = [-1, 0, 1, 2, 3, 4, 2, 0]; // cycles every 8 tiers
    final safeTier = tier <= 0 ? 1 : tier;
    final idx = (safeTier - 1) % semitoneOffsets.length;
    final semis = semitoneOffsets[idx];
    final r = pow(2, semis / 12).toDouble();
    final clamped = r.clamp(0.95, 1.2);
    return clamped.toDouble();
  }

  // ========== Public SFX API ==========
  Future<void> playMergeSound() async {
    if (!_soundEnabled) return;
    final variants = ['audio/FX/merge1.wav', 'audio/FX/merge2.wav', 'audio/FX/merge3.wav'];
    final pick = variants[_rand.nextInt(variants.length)];
    await _playSfx(pick, volume: 0.9, caption: 'Merge');
  }

  Future<void> playMergeSoundTuned({required int tier, required int selectionCount}) async {
    if (!_soundEnabled) return;
    // Unique per-tier signature: deterministic variant + musical pitch mapping.
    final baseRate = _rateForTier(tier);
    final micro = ((selectionCount.clamp(2, 8) - 3) * 0.01).toDouble(); // tiny emphasis for larger merges
    final double rate = (baseRate * (1.0 + micro)).clamp(0.95, 1.22);
    final variants = ['audio/FX/merge1.wav', 'audio/FX/merge2.wav', 'audio/FX/merge3.wav'];
    final pick = variants[((tier <= 0 ? 1 : tier) - 1) % variants.length];
    await _playSfx(pick, volume: 0.95, caption: 'Merge Tier $tier', playbackRate: rate);
  }

  Future<void> playSuccessSound() async {
    await _playSfx('audio/FX/boughtfromshop.wav', caption: 'Purchase successful');
  }

  Future<void> playClickSound() async {
    await _playSfx('audio/FX/selectitem.wav', volume: 0.6, caption: 'Item selected');
  }

  Future<void> playAbilityUseSound() async {
    await _playSfx('audio/FX/abilityuse.wav', caption: 'Ability used');
  }

  Future<void> playBombSound() async {
    await _playSfx('audio/FX/bomb.wav', caption: 'Bomb activated');
  }

  Future<void> playLevelUp() async {
    await _playSfx('audio/FX/levelUp.wav', caption: 'Level up');
  }

  Future<void> _maybeAnnounce(String text) async {
    try {
      // Avoid engine asserts on web and when semantics are disabled
      if (kIsWeb) return;
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      if (!dispatcher.semanticsEnabled) return;
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('a11y_audio_desc') ?? false;
      if (enabled) {
        SemanticsService.announce(text, TextDirection.ltr);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    super.dispose();
  }
}
