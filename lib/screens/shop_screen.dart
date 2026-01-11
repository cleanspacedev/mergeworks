import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/shop_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/models/shop_item.dart';
import 'package:mergeworks/theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magic Shop'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer2<ShopService, GameService>(
        builder: (context, shopService, gameService, child) {
          final energyItems = shopService.items.where((item) => item.type == ShopItemType.energy).toList();
          final gemItems = shopService.items.where((item) => item.type == ShopItemType.gems).toList();
          final specialItems = shopService.items.where((item) => item.type == ShopItemType.adRemoval).toList();

          return ListView(
            padding: AppSpacing.paddingMd,
            children: [
              _buildSection(
                context,
                'Energy Refills ⚡',
                'Get back in the game instantly',
                energyItems,
                shopService,
                gameService,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                'Magical Gems 💎',
                'Premium currency for special items',
                gemItems,
                shopService,
                gameService,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                'Special Offers 🎁',
                'One-time purchases',
                specialItems,
                shopService,
                gameService,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String subtitle,
    List<ShopItem> items,
    ShopService shopService,
    GameService gameService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textStyles.headlineSmall?.bold.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: context.textStyles.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...items.map((item) => _ShopItemCard(
          item: item,
          onPurchase: () => _handlePurchase(context, item, shopService, gameService),
        )),
      ],
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    ShopItem item,
    ShopService shopService,
    GameService gameService,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await shopService.purchase(item.id);
    
    if (context.mounted) {
      Navigator.of(context).pop();

      if (success) {
        if (item.type == ShopItemType.energy && item.energyAmount != null) {
          await gameService.addEnergy(item.energyAmount!);
        } else if (item.type == ShopItemType.gems && item.gemAmount != null) {
          await gameService.addGems(item.gemAmount!);
        }

        _showMessage(context, 'Purchase successful! 🎉', isError: false);
      } else {
        _showMessage(context, 'Purchase failed. Please try again.', isError: true);
      }
    }
  }

  void _showMessage(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onPurchase;

  const _ShopItemCard({
    required this.item,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onPurchase,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    item.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: context.textStyles.titleMedium?.bold.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: context.textStyles.titleMedium?.bold.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
