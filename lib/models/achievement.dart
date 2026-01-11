import 'package:cloud_firestore/cloud_firestore.dart';

class Achievement {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final String icon;
  final int targetValue;
  final int currentValue;
  final bool isCompleted;
  final int rewardGems;
  final AchievementType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  Achievement({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetValue,
    this.currentValue = 0,
    this.isCompleted = false,
    this.rewardGems = 10,
    required this.type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Achievement copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? icon,
    int? targetValue,
    int? currentValue,
    bool? isCompleted,
    int? rewardGems,
    AchievementType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Achievement(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    targetValue: targetValue ?? this.targetValue,
    currentValue: currentValue ?? this.currentValue,
    isCompleted: isCompleted ?? this.isCompleted,
    rewardGems: rewardGems ?? this.rewardGems,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  double get progress => currentValue / targetValue;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'title': title,
    'description': description,
    'icon': icon,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'isCompleted': isCompleted,
    'rewardGems': rewardGems,
    'type': type.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Achievement.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }
    
    return Achievement(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
    description: json['description'],
    icon: json['icon'],
    targetValue: json['targetValue'],
    currentValue: json['currentValue'],
    isCompleted: json['isCompleted'],
    rewardGems: json['rewardGems'],
    type: AchievementType.values.firstWhere((e) => e.name == json['type']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}

enum AchievementType {
  merges,
  tier,
  collection,
  daily,
}
