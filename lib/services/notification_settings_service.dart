import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService extends ChangeNotifier {
  static const String _levelUpPopupsKey = 'settings_level_up_popups_enabled';

  bool _levelUpPopupsEnabled = false;
  bool get levelUpPopupsEnabled => _levelUpPopupsEnabled;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _levelUpPopupsEnabled = prefs.getBool(_levelUpPopupsKey) ?? false;
    } catch (e) {
      debugPrint('NotificationSettingsService.initialize failed: $e');
      _levelUpPopupsEnabled = false;
    }
    notifyListeners();
  }

  Future<void> setLevelUpPopupsEnabled(bool value) async {
    _levelUpPopupsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_levelUpPopupsKey, value);
    } catch (e) {
      debugPrint('NotificationSettingsService.setLevelUpPopupsEnabled failed: $e');
    }
  }
}
