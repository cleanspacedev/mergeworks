import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String _playerStatsKey = 'player_stats';
  static const String _gridItemsKey = 'grid_items';
  static const String _achievementsKey = 'achievements';
  static const String _dailyQuestsKey = 'daily_quests';
  static const String _lastSpinKey = 'last_spin';

  Future<void> savePlayerStats(Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playerStatsKey, jsonEncode(stats));
    } catch (e) {
      debugPrint('Failed to save player stats: $e');
    }
  }

  Future<Map<String, dynamic>?> loadPlayerStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_playerStatsKey);
      if (data != null) {
        return jsonDecode(data);
      }
    } catch (e) {
      debugPrint('Failed to load player stats: $e');
    }
    return null;
  }

  Future<void> saveGridItems(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_gridItemsKey, jsonEncode(items));
    } catch (e) {
      debugPrint('Failed to save grid items: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadGridItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_gridItemsKey);
      if (data != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint('Failed to load grid items: $e');
    }
    return [];
  }

  Future<void> saveAchievements(List<Map<String, dynamic>> achievements) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_achievementsKey, jsonEncode(achievements));
    } catch (e) {
      debugPrint('Failed to save achievements: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_achievementsKey);
      if (data != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint('Failed to load achievements: $e');
    }
    return [];
  }

  Future<void> saveDailyQuests(List<Map<String, dynamic>> quests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyQuestsKey, jsonEncode(quests));
    } catch (e) {
      debugPrint('Failed to save daily quests: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadDailyQuests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_dailyQuestsKey);
      if (data != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint('Failed to load daily quests: $e');
    }
    return [];
  }

  Future<void> saveLastSpinDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSpinKey, date.toIso8601String());
    } catch (e) {
      debugPrint('Failed to save last spin date: $e');
    }
  }

  Future<DateTime?> loadLastSpinDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_lastSpinKey);
      if (data != null) {
        return DateTime.parse(data);
      }
    } catch (e) {
      debugPrint('Failed to load last spin date: $e');
    }
    return null;
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Failed to clear data: $e');
    }
  }
}
