import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mergeworks/models/shop_item.dart';

class ShopService extends ChangeNotifier {
  // ===== Store product mapping (internal -> store productId) =====
  // iOS/Android share the same product IDs you created in the stores.
  static const Map<String, String> _storeIds = {
    // Energy
    'energy_100': 'consumable.energy.100',
    'energy_500': 'consumable.energy.500',
    // Gems
    'gems_100': 'consumable.gems.100',
    'gems_500': 'consumable.gems.500',
    'gems_1200': 'consumable.gems.1200',
    // Non-consumable
    'ad_removal': 'nonconsumable.remove_adsAll',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  bool _iapAvailable = false;
  bool get iapAvailable => _iapAvailable;
  bool get isSimulated => kIsWeb || !_iapAvailable;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _productDetailsByItemId = {};

  Future<void> initialize() async {
    // In Dreamflow preview (web), native IAP is unavailable; we simulate.
    if (kIsWeb) {
      _iapAvailable = false;
      debugPrint('IAP: running on web, using simulation mode');
      notifyListeners();
      return;
    }
    try {
      _iapAvailable = await _iap.isAvailable();
      debugPrint('IAP: isAvailable() -> $_iapAvailable');
      if (_iapAvailable) {
        await _loadProducts();
        _purchaseSub ??= _iap.purchaseStream.listen(_onPurchaseUpdates, onError: (e) {
          debugPrint('IAP purchase stream error: $e');
        });
      } else {
        debugPrint('IAP: Store not available (device not signed to App Store/Play or capability missing)');
      }
    } catch (e) {
      debugPrint('IAP initialize failed: $e');
      _iapAvailable = false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ids = _storeIds.values.toSet();
      debugPrint('IAP: querying product details for: ' + ids.join(', '));
      final response = await _iap.queryProductDetails(ids);
      if (response.error != null) {
        debugPrint('IAP query error: ${response.error}');
      }
      _productDetailsByItemId.clear();
      final byId = {for (final p in response.productDetails) p.id: p};
      debugPrint('IAP: received ${response.productDetails.length} products: ' + byId.keys.join(', '));
      for (final entry in _storeIds.entries) {
        final pd = byId[entry.value];
        if (pd != null) {
          _productDetailsByItemId[entry.key] = pd;
        } else {
          debugPrint('IAP: missing product for itemId=${entry.key} storeId=${entry.value}');
        }
      }
      // Update listeners so the UI can enable/disable purchase buttons accordingly
      notifyListeners();
    } catch (e) {
      debugPrint('IAP load products failed: $e');
    }
  }

  String? priceLabelFor(String itemId) {
    final pd = _productDetailsByItemId[itemId];
    return pd?.price; // Localized price string like "\$0.99" or "€0,99"
  }

  bool hasProductDetails(String itemId) => _productDetailsByItemId.containsKey(itemId);

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      // Always complete pending purchases to unblock the queue
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.error || p.status == PurchaseStatus.canceled) {
        if (p.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(p);
          } catch (e) {
            debugPrint('Failed to complete purchase ${p.productID}: $e');
          }
        }
      }
    }
  }
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
    ShopItem(
      id: 'special_auto_select_upgrade',
      name: 'Auto-Select Upgrade',
      description: 'Hold on an item to auto-select closest items (up to 10).',
      icon: '🧠',
      price: 0.0,
      type: ShopItemType.special,
      gemCost: 160,
      requiredLevel: 2,
    ),
  ];

  List<ShopItem> get items => _items;

  Future<bool> purchase(String itemId) async {
    // Simulate in web/when store is not available
    if (isSimulated) {
      debugPrint('Simulating purchase for $itemId');
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    }

    try {
      final storeId = _storeIds[itemId];
      if (storeId == null) {
        debugPrint('No storeId mapping for $itemId');
        return false;
      }
      var pd = _productDetailsByItemId[itemId];
      if (pd == null) {
        await _loadProducts();
        pd = _productDetailsByItemId[itemId];
        if (pd == null) {
          debugPrint('ProductDetails not found for $itemId / $storeId');
          return false;
        }
      }

      final isConsumable = itemId != 'ad_removal';
      final targetId = pd.id;
      final completer = Completer<bool>();

      late final StreamSubscription sub;
      sub = _iap.purchaseStream.listen((purchases) async {
        for (final p in purchases) {
          if (p.productID != targetId) continue;
          switch (p.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              try {
                // On Android, consumables are auto-consumed when using buyConsumable with autoConsume=true
                if (p.pendingCompletePurchase) {
                  await _iap.completePurchase(p);
                }
              } catch (e) {
                debugPrint('Complete purchase failed: $e');
              }
              if (!completer.isCompleted) completer.complete(true);
              await sub.cancel();
              break;
            case PurchaseStatus.canceled:
            case PurchaseStatus.error:
              if (p.pendingCompletePurchase) {
                try { await _iap.completePurchase(p); } catch (_) {}
              }
              if (!completer.isCompleted) completer.complete(false);
              await sub.cancel();
              break;
          }
        }
      }, onError: (e) async {
        debugPrint('Purchase stream error: $e');
        if (!completer.isCompleted) completer.complete(false);
        await sub.cancel();
      });

      final param = PurchaseParam(productDetails: pd);
      final triggered = isConsumable
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: true)
          : await _iap.buyNonConsumable(purchaseParam: param);

      if (!triggered) {
        await sub.cancel();
        return false;
      }

      final ok = await completer.future.timeout(const Duration(seconds: 60), onTimeout: () => false);
      return ok;
    } catch (e) {
      debugPrint('purchase($itemId) failed: $e');
      return false;
    }
  }
}
