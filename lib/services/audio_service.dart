import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

class AudioService extends ChangeNotifier {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final Random _rand = Random();
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
      // Prepare background music looping
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
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

  // ========== Background Music ==========
  Future<void> _startBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setSource(AssetSource('assets/audio/Music/bgmusic.wav'));
      await _musicPlayer.resume();
    } catch (e) {
      debugPrint('Failed to start background music: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (e) {
      debugPrint('Failed to stop background music: $e');
    }
  }

  // ========== SFX Helpers ==========
  Future<void> _playSfx(String assetPath, {double volume = 1.0}) async {
    if (!_soundEnabled) return;
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        try { player.dispose(); } catch (_) {}
      });
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('SFX play failed ($assetPath): $e');
    }
  }

  // ========== Public SFX API ==========
  Future<void> playMergeSound() async {
    if (!_soundEnabled) return;
    final variants = ['assets/audio/FX/merge1.wav', 'assets/audio/FX/merge2.wav', 'assets/audio/FX/merge3.wav'];
    final pick = variants[_rand.nextInt(variants.length)];
    await _playSfx(pick, volume: 0.9);
  }

  Future<void> playSuccessSound() async {
    // Used for successful shop purchase popup
    await _playSfx('assets/audio/FX/boughtfromshop.wav');
  }

  Future<void> playClickSound() async {
    // Item selection tap
    await _playSfx('assets/audio/FX/selectitem.wav', volume: 0.6);
  }

  Future<void> playAbilityUseSound() async {
    await _playSfx('assets/audio/FX/abilityuse.wav');
  }

  Future<void> playBombSound() async {
    await _playSfx('assets/audio/FX/bomb.wav');
  }

  Future<void> playLevelUp() async {
    await _playSfx('assets/audio/FX/levelUp.wav');
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    super.dispose();
  }
}
