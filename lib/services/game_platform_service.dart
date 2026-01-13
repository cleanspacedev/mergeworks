import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:mergeworks/services/game_platform_config.dart';

class GamePlatformService extends ChangeNotifier {
  bool _signedIn = false;
  bool get signedIn => _signedIn;

  // Only Android/iOS are supported; web should no-op.
  bool get isAvailable => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isAvailable) {
      _signedIn = false;
      debugPrint('GamesServices init skipped: unsupported platform (${kIsWeb ? 'web' : defaultTargetPlatform.toString()})');
      notifyListeners();
      return;
    }
    try {
      await GamesServices.signIn();
      _signedIn = true;
      debugPrint('GamesServices: signed in');
    } catch (e) {
      _signedIn = false;
      debugPrint('GamesServices sign-in failed: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> showLeaderboards() async {
    if (!isAvailable) {
      debugPrint('Show leaderboards skipped: unsupported platform');
      return;
    }
    try {
      await GamesServices.showLeaderboards();
    } catch (e) {
      debugPrint('Failed to show leaderboards: $e');
    }
  }

  Future<void> showAchievements() async {
    if (!isAvailable) {
      debugPrint('Show achievements skipped: unsupported platform');
      return;
    }
    try {
      await GamesServices.showAchievements();
    } catch (e) {
      debugPrint('Failed to show achievements: $e');
    }
  }

  Future<void> submitAllScores({required int totalMerges, required int highestTier, required int level}) async {
    if (!isAvailable) {
      // Avoid throwing on web where the plugin isn't registered.
      return;
    }
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: GamePlatformIds.leaderboardTotalMerges,
          iOSLeaderboardID: GamePlatformIds.leaderboardTotalMerges,
          value: totalMerges.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('Submit score (Total Merges) failed: $e');
    }
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: GamePlatformIds.leaderboardHighestTier,
          iOSLeaderboardID: GamePlatformIds.leaderboardHighestTier,
          value: highestTier.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('Submit score (Highest Tier) failed: $e');
    }
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: GamePlatformIds.leaderboardPlayerLevel,
          iOSLeaderboardID: GamePlatformIds.leaderboardPlayerLevel,
          value: level.toInt(),
        ),
      );
    } catch (e) {
      debugPrint('Submit score (Level) failed: $e');
    }
  }

  Future<void> unlock(String achievementId) async {
    if (!isAvailable) return;
    try {
      await GamesServices.unlock(achievement: Achievement(androidID: achievementId, iOSID: achievementId));
    } catch (e) {
      debugPrint('Unlock achievement failed: $e');
    }
  }

  Future<void> increment(String achievementId, {int steps = 1}) async {
    if (!isAvailable) return;
    try {
      await GamesServices.increment(achievement: Achievement(androidID: achievementId, iOSID: achievementId, steps: steps));
    } catch (e) {
      debugPrint('Increment achievement failed: $e');
    }
  }
}
