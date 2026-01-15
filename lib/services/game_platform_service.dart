import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:mergeworks/services/game_platform_config.dart';

class GamePlatformService extends ChangeNotifier {
  bool _signedIn = false;
  bool get signedIn => _signedIn;

  // Only Android/iOS are supported; web should no-op.
  bool get isAvailable => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // Throttle repeated sign-in attempts to avoid noisy PlatformExceptions when user/capability is unavailable.
  DateTime? _lastSignInAttemptAt;
  static const Duration _signInRetryCooldown = Duration(minutes: 5);

  Future<void> initialize() async {
    if (!isAvailable) {
      _signedIn = false;
      debugPrint('GamesServices init skipped: unsupported platform (${kIsWeb ? 'web' : defaultTargetPlatform.toString()})');
      notifyListeners();
      return;
    }
    try {
      // Small delay to let Game Center bootstrap on app start
      await Future.delayed(const Duration(milliseconds: 300));
      _lastSignInAttemptAt = DateTime.now();
      await GamesServices.signIn();
      _signedIn = true;
      debugPrint('GamesServices: signed in');
    } catch (e) {
      _signedIn = false;
      debugPrint('GamesServices sign-in failed (startup): $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _ensureSignedIn() async {
    if (!isAvailable) return;
    if (_signedIn) return;

    // Respect cooldown after a failed attempt to prevent repeated failures.
    final now = DateTime.now();
    if (_lastSignInAttemptAt != null && now.difference(_lastSignInAttemptAt!) < _signInRetryCooldown) {
      debugPrint('GamesServices: sign-in throttled; will retry after cooldown');
      return;
    }

    try {
      _lastSignInAttemptAt = now;
      await GamesServices.signIn();
      _signedIn = true;
      debugPrint('GamesServices: re-signed in on demand');
    } catch (e) {
      _signedIn = false;
      debugPrint('GamesServices on-demand sign-in failed (cooldown ${_signInRetryCooldown.inMinutes}m): $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> showLeaderboards() async {
    if (!isAvailable) {
      debugPrint('Show leaderboards skipped: unsupported platform');
      return;
    }
    await _ensureSignedIn();
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
    await _ensureSignedIn();
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
    // Ensure we are signed in before attempting to send any scores
    await _ensureSignedIn();
    if (!_signedIn) {
      debugPrint('Submit scores skipped: Game Center/Play Games not signed in');
      return;
    }
    // Give the platform a brief moment after sign-in on iOS
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      debugPrint('Submitting score Total Merges -> ${GamePlatformIds.leaderboardTotalMerges}: $totalMerges');
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
      debugPrint('Submitting score Highest Tier -> ${GamePlatformIds.leaderboardHighestTier}: $highestTier');
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
      debugPrint('Submitting score Player Level -> ${GamePlatformIds.leaderboardPlayerLevel}: $level');
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
