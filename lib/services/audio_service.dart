import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
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

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      _musicVolume = (prefs.getDouble('music_volume') ?? 1.0).clamp(0.0, 1.0);
      _sfxVolume = (prefs.getDouble('sfx_volume') ?? 1.0).clamp(0.0, 1.0);
      // Prepare background music looping
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      if (_musicEnabled) {
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

  // ========== Background Music ==========
  Future<void> _startBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setSource(AssetSource('assets/audio/Music/bgmusic.wav'));
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.resume();
      debugPrint('MUSIC: Background music started');
    } catch (e) {
      debugPrint('Failed to start background music: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      debugPrint('MUSIC: Background music stopped');
    } catch (e) {
      debugPrint('Failed to stop background music: $e');
    }
  }

  // ========== SFX Helpers ==========
  Future<void> _playSfx(String assetPath, {double volume = 1.0, String? caption}) async {
    if (!_soundEnabled) return;
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        try { player.dispose(); } catch (_) {}
      });
      await player.setReleaseMode(ReleaseMode.stop);
      final effective = (volume * _sfxVolume).clamp(0.0, 1.0);
      await player.setVolume(effective);
      await player.play(AssetSource(assetPath));
      if (caption != null) {
        debugPrint('SFX: $caption');
        await _maybeAnnounce(caption);
      }
    } catch (e) {
      debugPrint('SFX play failed ($assetPath): $e');
    }
  }

  // ========== Public SFX API ==========
  Future<void> playMergeSound() async {
    if (!_soundEnabled) return;
    final variants = ['assets/audio/FX/merge1.wav', 'assets/audio/FX/merge2.wav', 'assets/audio/FX/merge3.wav'];
    final pick = variants[_rand.nextInt(variants.length)];
    await _playSfx(pick, volume: 0.9, caption: 'Merge');
  }

  Future<void> playSuccessSound() async {
    await _playSfx('assets/audio/FX/boughtfromshop.wav', caption: 'Purchase successful');
  }

  Future<void> playClickSound() async {
    await _playSfx('assets/audio/FX/selectitem.wav', volume: 0.6, caption: 'Item selected');
  }

  Future<void> playAbilityUseSound() async {
    await _playSfx('assets/audio/FX/abilityuse.wav', caption: 'Ability used');
  }

  Future<void> playBombSound() async {
    await _playSfx('assets/audio/FX/bomb.wav', caption: 'Bomb activated');
  }

  Future<void> playLevelUp() async {
    await _playSfx('assets/audio/FX/levelUp.wav', caption: 'Level up');
  }

  Future<void> _maybeAnnounce(String text) async {
    try {
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
