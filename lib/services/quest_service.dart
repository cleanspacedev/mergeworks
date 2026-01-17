import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/models/daily_quest.dart';
import 'package:mergeworks/models/player_stats.dart';
import 'package:mergeworks/services/firebase_service.dart';

class QuestService extends ChangeNotifier {
  FirebaseService? _firebaseService;
  List<DailyQuest> _quests = [];
  List<DailyQuest> _eventQuests = [];

  List<DailyQuest> get quests => _quests;
  List<DailyQuest> get activeQuests => _quests.where((q) => !q.isCompleted && q.expiresAt.isAfter(DateTime.now())).toList();
  List<DailyQuest> get completedQuests => _quests.where((q) => q.isCompleted).toList();

  List<DailyQuest> get eventQuests => _eventQuests;
  List<DailyQuest> get activeEventQuests => _eventQuests.where((q) => !q.isCompleted && q.expiresAt.isAfter(DateTime.now())).toList();
  List<DailyQuest> get completedEventQuests => _eventQuests.where((q) => q.isCompleted).toList();
  
  void setFirebaseService(FirebaseService service) {
    _firebaseService = service;
    _firebaseService!.addListener(_onAuthStateChanged);
    if (_firebaseService!.isInitialized && _firebaseService!.isAuthenticated) {
      initialize();
    }
  }
  
  void _onAuthStateChanged() {
    if (_firebaseService!.isAuthenticated) {
      initialize();
    }
  }

  Future<void> initialize() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) {
      debugPrint('Skipping QuestService init: Firebase not ready');
      return;
    }
    
    try {
      final userId = _firebaseService!.userId!;
      final querySnapshot = await _firebaseService!.firestore
          .collection('daily_quests')
          .where('user_id', isEqualTo: userId)
          .orderBy('expiresAt', descending: true)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _quests = querySnapshot.docs
            .map((doc) => DailyQuest.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
        _cleanupExpiredQuests();
      }
      
      if (_quests.isEmpty || _shouldGenerateNewQuests()) {
        _generateDailyQuests();
      }

      // Weekly event quests
      final eventSnap = await _firebaseService!.firestore
          .collection('event_quests')
          .where('user_id', isEqualTo: userId)
          .orderBy('expiresAt', descending: true)
          .get();
      if (eventSnap.docs.isNotEmpty) {
        _eventQuests = eventSnap.docs.map((doc) => DailyQuest.fromJson({...doc.data(), 'id': doc.id})).toList();
        _cleanupExpiredEventQuests();
      }
      if (_eventQuests.isEmpty || _shouldGenerateNewEventQuests()) {
        _generateWeeklyEventQuests();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize quests: $e');
      _generateDailyQuests();
      _generateWeeklyEventQuests();
    }
  }

  bool _shouldGenerateNewQuests() {
    if (_quests.isEmpty) return true;
    final now = DateTime.now();
    return _quests.every((q) => q.expiresAt.isBefore(now));
  }

  void _cleanupExpiredQuests() {
    final now = DateTime.now();
    _quests.removeWhere((q) => q.expiresAt.isBefore(now) && q.isCompleted);
  }

  bool _shouldGenerateNewEventQuests() {
    if (_eventQuests.isEmpty) return true;
    final now = DateTime.now();
    return _eventQuests.every((q) => q.expiresAt.isBefore(now));
  }

  void _cleanupExpiredEventQuests() {
    final now = DateTime.now();
    _eventQuests.removeWhere((q) => q.expiresAt.isBefore(now) && q.isCompleted);
  }

  void _generateDailyQuests() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    _quests = [
      DailyQuest(
        id: 'daily_merge_${now.millisecondsSinceEpoch}',
        title: 'Merge 20 Items',
        description: 'Complete 20 merges today',
        targetValue: 20,
        rewardGems: 15,
        rewardCoins: 100,
        type: QuestType.merge,
        expiresAt: tomorrow,
      ),
      DailyQuest(
        id: 'daily_tier_${now.millisecondsSinceEpoch}',
        title: 'Reach Tier 7',
        description: 'Create an item of tier 7 or higher',
        targetValue: 7,
        rewardGems: 25,
        rewardCoins: 150,
        type: QuestType.reachTier,
        expiresAt: tomorrow,
      ),
      DailyQuest(
        id: 'daily_collect_${now.millisecondsSinceEpoch}',
        title: 'Discover 3 Items',
        description: 'Discover 3 new items today',
        targetValue: 3,
        rewardGems: 20,
        rewardCoins: 120,
        type: QuestType.collectItems,
        expiresAt: tomorrow,
      ),
    ];
    
    _saveQuests();
  }

  void _generateWeeklyEventQuests() {
    final now = DateTime.now();
    // End of week (Sunday 23:59:59 local time)
    final int daysToSunday = DateTime.sunday - now.weekday;
    final endOfWeekDay = DateTime(now.year, now.month, now.day + daysToSunday + 1);
    final endOfWeek = endOfWeekDay.subtract(const Duration(milliseconds: 1));

    final seed = '${now.year}_${now.month}_${now.day - (now.weekday - 1)}'; // Monday anchor
    _eventQuests = [
      DailyQuest(
        id: 'event_merge_$seed',
        title: 'Weekly Grinder',
        description: 'Complete 120 merges this week',
        targetValue: 120,
        rewardGems: 90,
        rewardCoins: 700,
        type: QuestType.merge,
        expiresAt: endOfWeek,
      ),
      DailyQuest(
        id: 'event_tier_$seed',
        title: 'Chase the Mythic',
        description: 'Reach tier 12 or higher this week',
        targetValue: 12,
        rewardGems: 120,
        rewardCoins: 900,
        type: QuestType.reachTier,
        expiresAt: endOfWeek,
      ),
      DailyQuest(
        id: 'event_collect_$seed',
        title: 'Collector Week',
        description: 'Discover 10 unique tiers this week',
        targetValue: 10,
        rewardGems: 110,
        rewardCoins: 800,
        type: QuestType.collectItems,
        expiresAt: endOfWeek,
      ),
    ];
    _saveEventQuests();
  }

  Future<List<DailyQuest>> checkProgress(PlayerStats stats) async {
    final completed = <DailyQuest>[];

    int computeValue(QuestType type) {
      switch (type) {
        case QuestType.merge:
          return stats.totalMerges;
        case QuestType.reachTier:
          return stats.highestTier;
        case QuestType.collectItems:
          return stats.discoveredItems.length;
      }
    }

    bool changedDaily = false;
    bool changedEvent = false;

    bool applyToList(List<DailyQuest> list) {
      bool changed = false;
      for (int i = 0; i < list.length; i++) {
        final quest = list[i];
        if (quest.isCompleted) continue;
        final currentValue = computeValue(quest.type);
        if (currentValue != quest.currentValue) {
          list[i] = quest.copyWith(currentValue: currentValue);
          changed = true;
        }
        if (currentValue >= quest.targetValue && !quest.isCompleted) {
          list[i] = list[i].copyWith(isCompleted: true, updatedAt: DateTime.now());
          completed.add(list[i]);
          changed = true;
        }
      }
      return changed;
    }

    changedDaily = applyToList(_quests);
    changedEvent = applyToList(_eventQuests);

    if (completed.isNotEmpty) {
      // Persist completed progress updates.
      await _saveQuests();
      await _saveEventQuests();
      notifyListeners();
    }

    // Even if nothing completed, keep progress synced.
    if (completed.isEmpty && (changedDaily || changedEvent)) {
      if (changedDaily) await _saveQuests();
      if (changedEvent) await _saveEventQuests();
      notifyListeners();
    }

    return completed;
  }

  Future<void> _saveQuests() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    
    try {
      final userId = _firebaseService!.userId!;
      final batch = _firebaseService!.firestore.batch();
      
      for (final quest in _quests) {
        final docRef = _firebaseService!.firestore
            .collection('daily_quests')
            .doc(quest.id);
        batch.set(docRef, quest.copyWith(userId: userId).toJson(), SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save quests: $e');
    }
  }

  Future<void> _saveEventQuests() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    try {
      final userId = _firebaseService!.userId!;
      final batch = _firebaseService!.firestore.batch();
      for (final quest in _eventQuests) {
        final docRef = _firebaseService!.firestore.collection('event_quests').doc(quest.id);
        batch.set(docRef, quest.copyWith(userId: userId).toJson(), SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save event quests: $e');
    }
  }
}
