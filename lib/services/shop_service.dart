import 'package:flutter/foundation.dart';
import 'package:mergeworks/models/shop_item.dart';

class ShopService extends ChangeNotifier {
  final List<ShopItem> _items = [
    ShopItem(
      id: 'energy_100',
      name: '100 Energy',
      description: 'Refill your energy instantly',
      icon: '⚡',
      price: 0.99,
      type: ShopItemType.energy,
      energyAmount: 100,
    ),
    ShopItem(
      id: 'energy_500',
      name: '500 Energy',
      description: 'Massive energy boost!',
      icon: '⚡',
      price: 3.99,
      type: ShopItemType.energy,
      energyAmount: 500,
    ),
    ShopItem(
      id: 'gems_100',
      name: '100 Gems',
      description: 'Handful of magical gems',
      icon: '💎',
      price: 1.99,
      type: ShopItemType.gems,
      gemAmount: 100,
    ),
    ShopItem(
      id: 'gems_500',
      name: '500 Gems',
      description: 'Pile of magical gems',
      icon: '💎',
      price: 4.99,
      type: ShopItemType.gems,
      gemAmount: 500,
    ),
    ShopItem(
      id: 'gems_1200',
      name: '1200 Gems',
      description: 'Treasure chest of gems',
      icon: '💎',
      price: 9.99,
      type: ShopItemType.gems,
      gemAmount: 1200,
    ),
    ShopItem(
      id: 'ad_removal',
      name: 'Remove Ads',
      description: 'Enjoy ad-free gameplay forever',
      icon: '🚫',
      price: 4.99,
      type: ShopItemType.adRemoval,
    ),
    // Specials (purchased with gems)
    ShopItem(
      id: 'special_wildcard_orb',
      name: 'Wildcard Orb',
      description: 'Place a 🃏 tile that merges with anything (1 use).',
      icon: '🃏',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 200,
      requiredLevel: 1,
    ),
    ShopItem(
      id: 'special_energy_booster',
      name: 'Energy Booster',
      description: '+50 Max Energy permanently, refills 50 energy now.',
      icon: '⚡',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 300,
      requiredLevel: 1,
    ),
    ShopItem(
      id: 'special_power_merge_pack',
      name: 'Power Merge Pack',
      description: '+3 Power Merge charges (merge 2 of a kind).',
      icon: '⚡️',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 150,
      requiredLevel: 2,
    ),
    ShopItem(
      id: 'special_bomb_rune',
      name: 'Bomb Rune',
      description: 'Clear a 3×3 area around a selected tile (1 use).',
      icon: '💣',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 180,
      requiredLevel: 2,
    ),
    ShopItem(
      id: 'special_tier_up',
      name: 'Ascension Shard',
      description: 'Upgrade any tile by +1 tier instantly (1 use).',
      icon: '⤴️',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 250,
      requiredLevel: 3,
    ),
    ShopItem(
      id: 'special_time_warp',
      name: 'Time Warp',
      description: 'Instantly gain +100 Energy right now.',
      icon: '⏳',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 120,
      requiredLevel: 1,
    ),
  ];

  List<ShopItem> get items => _items;

  Future<bool> purchase(String itemId) async {
    debugPrint('Simulating purchase for $itemId');
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
