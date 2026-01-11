import 'package:cloud_firestore/cloud_firestore.dart';

class DailyQuest {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final int targetValue;
  final int currentValue;
  final bool isCompleted;
  final int rewardGems;
  final int rewardCoins;
  final QuestType type;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyQuest({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.targetValue,
    this.currentValue = 0,
    this.isCompleted = false,
    this.rewardGems = 5,
    this.rewardCoins = 50,
    required this.type,
    required this.expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  DailyQuest copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? targetValue,
    int? currentValue,
    bool? isCompleted,
    int? rewardGems,
    int? rewardCoins,
    QuestType? type,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DailyQuest(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    description: description ?? this.description,
    targetValue: targetValue ?? this.targetValue,
    currentValue: currentValue ?? this.currentValue,
    isCompleted: isCompleted ?? this.isCompleted,
    rewardGems: rewardGems ?? this.rewardGems,
    rewardCoins: rewardCoins ?? this.rewardCoins,
    type: type ?? this.type,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  double get progress => currentValue / targetValue;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'title': title,
    'description': description,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'isCompleted': isCompleted,
    'rewardGems': rewardGems,
    'rewardCoins': rewardCoins,
    'type': type.name,
    'expiresAt': Timestamp.fromDate(expiresAt),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    
    return DailyQuest(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
    description: json['description'],
    targetValue: json['targetValue'],
    currentValue: json['currentValue'],
    isCompleted: json['isCompleted'],
    rewardGems: json['rewardGems'],
    rewardCoins: json['rewardCoins'],
    type: QuestType.values.firstWhere((e) => e.name == json['type']),
      expiresAt: parseDate(json['expiresAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

enum QuestType {
  merge,
  reachTier,
  collectItems,
}
