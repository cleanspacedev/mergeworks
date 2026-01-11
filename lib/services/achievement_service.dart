import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/models/achievement.dart';
import 'package:mergeworks/models/player_stats.dart';
import 'package:mergeworks/services/firebase_service.dart';

class AchievementService extends ChangeNotifier {
  FirebaseService? _firebaseService;
  List<Achievement> _achievements = [];

  List<Achievement> get achievements => _achievements;
  List<Achievement> get completedAchievements => _achievements.where((a) => a.isCompleted).toList();
  List<Achievement> get pendingAchievements => _achievements.where((a) => !a.isCompleted).toList();
  
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
      debugPrint('Skipping AchievementService init: Firebase not ready');
      return;
    }
    
    try {
      final userId = _firebaseService!.userId!;
      final querySnapshot = await _firebaseService!.firestore
          .collection('achievements')
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        _achievements = querySnapshot.docs
            .map((doc) => Achievement.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      } else {
        _initializeDefaultAchievements();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize achievements: $e');
      _initializeDefaultAchievements();
    }
  }

  void _initializeDefaultAchievements() {
    _achievements = [
      Achievement(
        id: 'first_merge',
        title: 'First Merge',
        description: 'Complete your first merge',
        icon: '✨',
        targetValue: 1,
        rewardGems: 10,
        type: AchievementType.merges,
      ),
      Achievement(
        id: 'merge_master',
        title: 'Merge Master',
        description: 'Complete 50 merges',
        icon: '⚡',
        targetValue: 50,
        rewardGems: 50,
        type: AchievementType.merges,
      ),
      Achievement(
        id: 'merge_legend',
        title: 'Merge Legend',
        description: 'Complete 200 merges',
        icon: '🔥',
        targetValue: 200,
        rewardGems: 100,
        type: AchievementType.merges,
      ),
      Achievement(
        id: 'tier_5',
        title: 'Rising Star',
        description: 'Reach tier 5',
        icon: '🌟',
        targetValue: 5,
        rewardGems: 25,
        type: AchievementType.tier,
      ),
      Achievement(
        id: 'tier_10',
        title: 'Master Mergeician',
        description: 'Reach tier 10',
        icon: '🪄',
        targetValue: 10,
        rewardGems: 75,
        type: AchievementType.tier,
      ),
      Achievement(
        id: 'tier_15',
        title: 'Legendary',
        description: 'Reach tier 15',
        icon: '🦄',
        targetValue: 15,
        rewardGems: 150,
        type: AchievementType.tier,
      ),
      Achievement(
        id: 'collector',
        title: 'Collector',
        description: 'Discover 8 different items',
        icon: '💎',
        targetValue: 8,
        rewardGems: 40,
        type: AchievementType.collection,
      ),
      Achievement(
        id: 'completionist',
        title: 'Completionist',
        description: 'Discover all 18 items',
        icon: '👑',
        targetValue: 18,
        rewardGems: 200,
        type: AchievementType.collection,
      ),
      Achievement(
        id: 'daily_1',
        title: 'Dedication',
        description: 'Login 7 days in a row',
        icon: '📅',
        targetValue: 7,
        rewardGems: 30,
        type: AchievementType.daily,
      ),
      Achievement(
        id: 'daily_2',
        title: 'Devotion',
        description: 'Login 30 days in a row',
        icon: '🎯',
        targetValue: 30,
        rewardGems: 100,
        type: AchievementType.daily,
      ),
    ];
    _saveAchievements();
  }

  Future<List<Achievement>> checkProgress(PlayerStats stats) async {
    final completed = <Achievement>[];

    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      if (achievement.isCompleted) continue;

      int currentValue = 0;
      switch (achievement.type) {
        case AchievementType.merges:
          currentValue = stats.totalMerges;
          break;
        case AchievementType.tier:
          currentValue = stats.highestTier;
          break;
        case AchievementType.collection:
          currentValue = stats.discoveredItems.length;
          break;
        case AchievementType.daily:
          currentValue = stats.loginStreak;
          break;
      }

      _achievements[i] = achievement.copyWith(currentValue: currentValue);

      if (currentValue >= achievement.targetValue && !achievement.isCompleted) {
        _achievements[i] = _achievements[i].copyWith(
          isCompleted: true,
          updatedAt: DateTime.now(),
        );
        completed.add(_achievements[i]);
      }
    }

    if (completed.isNotEmpty) {
      await _saveAchievements();
      notifyListeners();
    }

    return completed;
  }

  Future<void> _saveAchievements() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    
    try {
      final userId = _firebaseService!.userId!;
      final batch = _firebaseService!.firestore.batch();
      
      for (final achievement in _achievements) {
        final docRef = _firebaseService!.firestore
            .collection('achievements')
            .doc(achievement.id);
        batch.set(docRef, achievement.copyWith(userId: userId).toJson(), SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save achievements: $e');
    }
  }
}
