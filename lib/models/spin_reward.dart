class SpinReward {
  final String id;
  final String name;
  final String icon;
  final RewardType type;
  final int amount;
  final double probability;

  SpinReward({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.amount,
    required this.probability,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'type': type.name,
    'amount': amount,
    'probability': probability,
  };

  factory SpinReward.fromJson(Map<String, dynamic> json) => SpinReward(
    id: json['id'],
    name: json['name'],
    icon: json['icon'],
    type: RewardType.values.firstWhere((e) => e.name == json['type']),
    amount: json['amount'],
    probability: json['probability'],
  );
}

enum RewardType {
  gems,
  coins,
  energy,
}
