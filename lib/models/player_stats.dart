import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStats {
  final String? userId;
  final int energy;
  final int maxEnergy;
  final int gems;
  final int coins;
  final int totalMerges;
  final int highestTier;
  final DateTime lastEnergyUpdate;
  final List<String> discoveredItems;
  final int loginStreak;
  final DateTime? lastLoginDate;
  final bool hasCompletedTutorial;
  final bool adRemovalPurchased;
  final int wildcardOrbs; // inventory of wildcard consumables
  final int bombRunes; // clear 3x3 area consumable
  final int tierUpTokens; // upgrade item by +1 tier consumable
  final int autoSelectCount; // permanent: long-press selects up to this many items (0=disabled)

  // --- Meta progression ---
  final int seasonXp;
  final int seasonLevel;
  final int masteryXp;
  final int masteryLevel;

  // Town / workshop upgrades (simple sink)
  final int townCoinBonusLevel; // increases coins gained from merges
  final int townEnergyCapLevel; // increases max energy

  // Once-per-day skill escape
  final DateTime? lastMicroShuffleAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlayerStats({
    this.userId,
    this.energy = 50,
    this.maxEnergy = 100,
    this.gems = 0,
    this.coins = 0,
    this.totalMerges = 0,
    this.highestTier = 0,
    DateTime? lastEnergyUpdate,
    this.discoveredItems = const [],
    this.loginStreak = 0,
    this.lastLoginDate,
    this.hasCompletedTutorial = false,
    this.adRemovalPurchased = false,
    this.wildcardOrbs = 0,
    this.bombRunes = 0,
    this.tierUpTokens = 0,
    this.autoSelectCount = 0,
    this.seasonXp = 0,
    this.seasonLevel = 1,
    this.masteryXp = 0,
    this.masteryLevel = 1,
    this.townCoinBonusLevel = 0,
    this.townEnergyCapLevel = 0,
    this.lastMicroShuffleAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lastEnergyUpdate = lastEnergyUpdate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  PlayerStats copyWith({
    String? userId,
    int? energy,
    int? maxEnergy,
    int? gems,
    int? coins,
    int? totalMerges,
    int? highestTier,
    DateTime? lastEnergyUpdate,
    List<String>? discoveredItems,
    int? loginStreak,
    DateTime? lastLoginDate,
    bool? hasCompletedTutorial,
    bool? adRemovalPurchased,
    int? wildcardOrbs,
    int? bombRunes,
    int? tierUpTokens,
    int? autoSelectCount,
    int? seasonXp,
    int? seasonLevel,
    int? masteryXp,
    int? masteryLevel,
    int? townCoinBonusLevel,
    int? townEnergyCapLevel,
    DateTime? lastMicroShuffleAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlayerStats(
    userId: userId ?? this.userId,
    energy: energy ?? this.energy,
    maxEnergy: maxEnergy ?? this.maxEnergy,
    gems: gems ?? this.gems,
    coins: coins ?? this.coins,
    totalMerges: totalMerges ?? this.totalMerges,
    highestTier: highestTier ?? this.highestTier,
    lastEnergyUpdate: lastEnergyUpdate ?? this.lastEnergyUpdate,
    discoveredItems: discoveredItems ?? this.discoveredItems,
    loginStreak: loginStreak ?? this.loginStreak,
    lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    hasCompletedTutorial: hasCompletedTutorial ?? this.hasCompletedTutorial,
    adRemovalPurchased: adRemovalPurchased ?? this.adRemovalPurchased,
    wildcardOrbs: wildcardOrbs ?? this.wildcardOrbs,
    bombRunes: bombRunes ?? this.bombRunes,
    tierUpTokens: tierUpTokens ?? this.tierUpTokens,
    autoSelectCount: autoSelectCount ?? this.autoSelectCount,
    seasonXp: seasonXp ?? this.seasonXp,
    seasonLevel: seasonLevel ?? this.seasonLevel,
    masteryXp: masteryXp ?? this.masteryXp,
    masteryLevel: masteryLevel ?? this.masteryLevel,
    townCoinBonusLevel: townCoinBonusLevel ?? this.townCoinBonusLevel,
    townEnergyCapLevel: townEnergyCapLevel ?? this.townEnergyCapLevel,
    lastMicroShuffleAt: lastMicroShuffleAt ?? this.lastMicroShuffleAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user_id': userId,
    'energy': energy,
    'maxEnergy': maxEnergy,
    'gems': gems,
    'coins': coins,
    'totalMerges': totalMerges,
    'highestTier': highestTier,
    'lastEnergyUpdate': Timestamp.fromDate(lastEnergyUpdate),
    'discoveredItems': discoveredItems,
    'loginStreak': loginStreak,
    'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : null,
    'hasCompletedTutorial': hasCompletedTutorial,
    'adRemovalPurchased': adRemovalPurchased,
    'wildcardOrbs': wildcardOrbs,
    'bombRunes': bombRunes,
    'tierUpTokens': tierUpTokens,
    'autoSelectCount': autoSelectCount,
    'seasonXp': seasonXp,
    'seasonLevel': seasonLevel,
    'masteryXp': masteryXp,
    'masteryLevel': masteryLevel,
    'townCoinBonusLevel': townCoinBonusLevel,
    'townEnergyCapLevel': townEnergyCapLevel,
    'lastMicroShuffleAt': lastMicroShuffleAt != null ? Timestamp.fromDate(lastMicroShuffleAt!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    
    return PlayerStats(
      userId: json['user_id'],
      energy: json['energy'] ?? 50,
      maxEnergy: json['maxEnergy'] ?? 100,
      gems: json['gems'] ?? 0,
      coins: json['coins'] ?? 0,
      totalMerges: json['totalMerges'] ?? 0,
      highestTier: json['highestTier'] ?? 0,
      lastEnergyUpdate: parseDate(json['lastEnergyUpdate']),
      discoveredItems: json['discoveredItems'] != null ? List<String>.from(json['discoveredItems']) : [],
      loginStreak: json['loginStreak'] ?? 0,
      lastLoginDate: json['lastLoginDate'] != null ? parseDate(json['lastLoginDate']) : null,
      hasCompletedTutorial: json['hasCompletedTutorial'] ?? false,
      adRemovalPurchased: json['adRemovalPurchased'] ?? false,
      wildcardOrbs: json['wildcardOrbs'] ?? 0,
      bombRunes: json['bombRunes'] ?? 0,
      tierUpTokens: json['tierUpTokens'] ?? 0,
      autoSelectCount: json['autoSelectCount'] ?? 0,
      seasonXp: json['seasonXp'] ?? 0,
      seasonLevel: json['seasonLevel'] ?? 1,
      masteryXp: json['masteryXp'] ?? 0,
      masteryLevel: json['masteryLevel'] ?? 1,
      townCoinBonusLevel: json['townCoinBonusLevel'] ?? 0,
      townEnergyCapLevel: json['townEnergyCapLevel'] ?? 0,
      lastMicroShuffleAt: json['lastMicroShuffleAt'] != null ? parseDate(json['lastMicroShuffleAt']) : null,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
