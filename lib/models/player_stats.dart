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
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
