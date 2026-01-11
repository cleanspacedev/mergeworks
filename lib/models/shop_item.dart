class ShopItem {
  final String id;
  final String name;
  final String description;
  final String icon;
  final double price;
  final ShopItemType type;
  final int? gemAmount;
  final int? energyAmount;
  final bool isPurchased;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    required this.type,
    this.gemAmount,
    this.energyAmount,
    this.isPurchased = false,
  });

  ShopItem copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    double? price,
    ShopItemType? type,
    int? gemAmount,
    int? energyAmount,
    bool? isPurchased,
  }) => ShopItem(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    price: price ?? this.price,
    type: type ?? this.type,
    gemAmount: gemAmount ?? this.gemAmount,
    energyAmount: energyAmount ?? this.energyAmount,
    isPurchased: isPurchased ?? this.isPurchased,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'price': price,
    'type': type.name,
    'gemAmount': gemAmount,
    'energyAmount': energyAmount,
    'isPurchased': isPurchased,
  };

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    icon: json['icon'],
    price: json['price'],
    type: ShopItemType.values.firstWhere((e) => e.name == json['type']),
    gemAmount: json['gemAmount'],
    energyAmount: json['energyAmount'],
    isPurchased: json['isPurchased'] ?? false,
  );
}

enum ShopItemType {
  gems,
  energy,
  adRemoval,
}
