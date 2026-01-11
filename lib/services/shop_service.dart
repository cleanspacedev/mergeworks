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
  ];

  List<ShopItem> get items => _items;

  Future<bool> purchase(String itemId) async {
    debugPrint('Simulating purchase for $itemId');
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
