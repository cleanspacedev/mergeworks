/// Game Platform configuration for Game Center (iOS) and Google Play Games (Android)
///
/// Replace the IDs below with the ones you create in App Store Connect
/// and Google Play Console. Keep the same strings on both platforms when possible.
///
/// Naming scheme (reverse-DNS based on package id com.mergeworks.mergeworks):
/// - Leaderboards: com.mergeworks.mergeworks.leaderboard.<metric>
/// - Achievements: com.mergeworks.mergeworks.achievement.<milestone>
///
/// Reference Names (for console UIs) are human‑readable labels displayed to players.
/// They don't need to be unique across platforms, but IDs must be identical to what
/// you configure in each store.
class GamePlatformIds {
  // Leaderboards
  static const leaderboardTotalMerges = 'com.mergeworks.mergeworks.leaderboard.total_merges';
  static const leaderboardHighestTier = 'com.mergeworks.mergeworks.leaderboard.highest_tier';
  static const leaderboardPlayerLevel = 'com.mergeworks.mergeworks.leaderboard.player_level';

  // Achievements (examples)
  static const achieveFirstMerge = 'com.mergeworks.mergeworks.achievement.first_merge';
  static const achieveTier5 = 'com.mergeworks.mergeworks.achievement.reach_tier_5';
  static const achieveTier10 = 'com.mergeworks.mergeworks.achievement.reach_tier_10';
  static const achieveTier15 = 'com.mergeworks.mergeworks.achievement.reach_tier_15';
  static const achieveLevel5 = 'com.mergeworks.mergeworks.achievement.reach_level_5';
  static const achieveLevel10 = 'com.mergeworks.mergeworks.achievement.reach_level_10';

  /// Helper list to map to console creation
  static Map<String, String> get referenceNames => {
    leaderboardTotalMerges: 'Total Merges',
    leaderboardHighestTier: 'Highest Tier Reached',
    leaderboardPlayerLevel: 'Player Level',
    achieveFirstMerge: 'First Merge',
    achieveTier5: 'Reach Tier 5',
    achieveTier10: 'Reach Tier 10',
    achieveTier15: 'Reach Tier 15',
    achieveLevel5: 'Reach Level 5',
    achieveLevel10: 'Reach Level 10',
  };
}
