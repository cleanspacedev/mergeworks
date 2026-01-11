import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _musicEnabled = prefs.getBool('music_enabled') ?? true;
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
    notifyListeners();
  }

  Future<void> playMergeSound() async {
    if (!_soundEnabled) return;
    debugPrint('Playing merge sound');
  }

  Future<void> playSuccessSound() async {
    if (!_soundEnabled) return;
    debugPrint('Playing success sound');
  }

  Future<void> playClickSound() async {
    if (!_soundEnabled) return;
    debugPrint('Playing click sound');
  }

  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
