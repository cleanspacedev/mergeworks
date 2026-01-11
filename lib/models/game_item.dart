class GameItem {
  final String id;
  final String? userId;
  final String name;
  final int tier;
  final String emoji;
  final String description;
  final int? gridX;
  final int? gridY;
  final bool isDiscovered;
  final bool canBePurchased;
  final int? purchaseCost;

  GameItem({
    required this.id,
    this.userId,
    required this.name,
    required this.tier,
    required this.emoji,
    required this.description,
    this.gridX,
    this.gridY,
    this.isDiscovered = false,
    this.canBePurchased = false,
    this.purchaseCost,
  });

  GameItem copyWith({
    String? id,
    String? userId,
    String? name,
    int? tier,
    String? emoji,
    String? description,
    int? gridX,
    int? gridY,
    bool? isDiscovered,
    bool? canBePurchased,
    int? purchaseCost,
  }) => GameItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    tier: tier ?? this.tier,
    emoji: emoji ?? this.emoji,
    description: description ?? this.description,
    gridX: gridX ?? this.gridX,
    gridY: gridY ?? this.gridY,
    isDiscovered: isDiscovered ?? this.isDiscovered,
    canBePurchased: canBePurchased ?? this.canBePurchased,
    purchaseCost: purchaseCost ?? this.purchaseCost,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'user_id': userId,
    'name': name,
    'tier': tier,
    'emoji': emoji,
    'description': description,
    'gridX': gridX,
    'gridY': gridY,
    'isDiscovered': isDiscovered,
    'canBePurchased': canBePurchased,
    'purchaseCost': purchaseCost,
  };

  factory GameItem.fromJson(Map<String, dynamic> json) => GameItem(
    id: json['id'],
    userId: json['user_id'],
    name: json['name'],
    tier: json['tier'],
    emoji: json['emoji'],
    description: json['description'],
    gridX: json['gridX'],
    gridY: json['gridY'],
    isDiscovered: json['isDiscovered'] ?? false,
    canBePurchased: json['canBePurchased'] ?? false,
    purchaseCost: json['purchaseCost'],
  );
}
