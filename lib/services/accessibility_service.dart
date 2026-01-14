import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized accessibility and localization preferences.
/// All features are OFF by default.
class AccessibilityService extends ChangeNotifier {
  static const _prefsKey = 'a11y_settings';
  static const _kLargerText = 'larger_text';
  static const _kForceDark = 'force_dark';
  static const _kDifferentiate = 'differentiate_without_color';
  static const _kHighContrast = 'high_contrast';
  static const _kReducedMotion = 'reduced_motion';
  static const _kCaptions = 'captions_enabled';
  static const _kAudioDescriptions = 'audio_descriptions';
  static const _kVoiceOverHints = 'voice_over_hints';
  static const _kVoiceControlHints = 'voice_control_hints';

  bool largerText = false; // 200% when true
  // Default to dark mode ON from first launch
  bool forceDark = true;
  bool differentiateWithoutColor = false;
  bool highContrast = false;
  bool reducedMotion = false;
  bool captionsEnabled = false;
  bool audioDescriptions = false;
  bool voiceOverHints = false;
  bool voiceControlHints = false;

  double get textScale => largerText ? 2.0 : 1.0;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = prefs.getStringList(_prefsKey);
      // Simple compact storage: list of enabled keys
      if (map != null) {
        largerText = map.contains(_kLargerText);
        forceDark = map.contains(_kForceDark);
        differentiateWithoutColor = map.contains(_kDifferentiate);
        highContrast = map.contains(_kHighContrast);
        reducedMotion = map.contains(_kReducedMotion);
        captionsEnabled = map.contains(_kCaptions);
        audioDescriptions = map.contains(_kAudioDescriptions);
        voiceOverHints = map.contains(_kVoiceOverHints);
        voiceControlHints = map.contains(_kVoiceControlHints);
        // Migration: if prefs exist but are empty (legacy), default to dark and persist
        if (map.isEmpty) {
          forceDark = true;
          await _persist();
        }
      } else {
        // No stored settings yet; persist defaults (with dark mode enabled)
        await _persist();
      }
    } catch (e) {
      debugPrint('Failed to load a11y settings: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = <String>[];
      if (largerText) enabled.add(_kLargerText);
      if (forceDark) enabled.add(_kForceDark);
      if (differentiateWithoutColor) enabled.add(_kDifferentiate);
      if (highContrast) enabled.add(_kHighContrast);
      if (reducedMotion) enabled.add(_kReducedMotion);
      if (captionsEnabled) enabled.add(_kCaptions);
      if (audioDescriptions) enabled.add(_kAudioDescriptions);
      if (voiceOverHints) enabled.add(_kVoiceOverHints);
      if (voiceControlHints) enabled.add(_kVoiceControlHints);
      await prefs.setStringList(_prefsKey, enabled);
      // Also mirror audio descriptions to a simple flag for services without access to provider
      await prefs.setBool('a11y_audio_desc', audioDescriptions);
    } catch (e) {
      debugPrint('Failed to save a11y settings: $e');
    }
  }

  void setLargerText(bool v) { largerText = v; _persist(); notifyListeners(); }
  void setForceDark(bool v) { forceDark = v; _persist(); notifyListeners(); }
  void setDifferentiateWithoutColor(bool v) { differentiateWithoutColor = v; _persist(); notifyListeners(); }
  void setHighContrast(bool v) { highContrast = v; _persist(); notifyListeners(); }
  void setReducedMotion(bool v) { reducedMotion = v; _persist(); notifyListeners(); }
  void setCaptionsEnabled(bool v) { captionsEnabled = v; _persist(); notifyListeners(); }
  void setAudioDescriptions(bool v) { audioDescriptions = v; _persist(); notifyListeners(); }
  void setVoiceOverHints(bool v) { voiceOverHints = v; _persist(); notifyListeners(); }
  void setVoiceControlHints(bool v) { voiceControlHints = v; _persist(); notifyListeners(); }
}
