import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/models/daily_quest.dart';
import 'package:mergeworks/models/player_stats.dart';
import 'package:mergeworks/services/firebase_service.dart';

class QuestService extends ChangeNotifier {
  FirebaseService? _firebaseService;
  List<DailyQuest> _quests = [];

  List<DailyQuest> get quests => _quests;
  List<DailyQuest> get activeQuests => _quests.where((q) => !q.isCompleted && q.expiresAt.isAfter(DateTime.now())).toList();
  List<DailyQuest> get completedQuests => _quests.where((q) => q.isCompleted).toList();
  
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
          .orderBy('expires_at', descending: true)
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
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize quests: $e');
      _generateDailyQuests();
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

  Future<List<DailyQuest>> checkProgress(PlayerStats stats) async {
    final completed = <DailyQuest>[];

    for (int i = 0; i < _quests.length; i++) {
      final quest = _quests[i];
      if (quest.isCompleted) continue;

      int currentValue = 0;
      switch (quest.type) {
        case QuestType.merge:
          currentValue = stats.totalMerges;
          break;
        case QuestType.reachTier:
          currentValue = stats.highestTier;
          break;
        case QuestType.collectItems:
          currentValue = stats.discoveredItems.length;
          break;
      }

      _quests[i] = quest.copyWith(currentValue: currentValue);

      if (currentValue >= quest.targetValue && !quest.isCompleted) {
        _quests[i] = _quests[i].copyWith(
          isCompleted: true,
          updatedAt: DateTime.now(),
        );
        completed.add(_quests[i]);
      }
    }

    if (completed.isNotEmpty) {
      await _saveQuests();
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
}
