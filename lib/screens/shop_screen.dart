import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/shop_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/models/shop_item.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/haptics_service.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/widgets/particle_field.dart';

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
          final specials = shopService.items.where((item) => item.type == ShopItemType.special || item.type == ShopItemType.adRemoval).toList();

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
                'Specials ✨',
                'Consumables and upgrades (paid with gems)',
                specials,
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
        ...items.map((item) {
          final isSpecial = item.type == ShopItemType.special;
          final isLocked = isSpecial && item.requiredLevel > gameService.currentLevel;
          return _ShopItemCard(
            item: item,
            isLocked: isLocked,
            lockLabel: isLocked ? 'Reach Level ${item.requiredLevel}' : null,
            onPurchase: isLocked ? null : () => _handlePurchase(context, item, shopService, gameService),
          );
        }),
      ],
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    ShopItem item,
    ShopService shopService,
    GameService gameService,
  ) async {
    // Specials are purchased with gems and applied instantly in-game
    if (item.type == ShopItemType.special) {
      final ok = await gameService.purchaseSpecial(item.id, item.gemCost ?? 0);
      if (ok) {
        _showPurchasePopup(context, title: 'Purchased!', subtitle: item.name, emoji: item.icon);
      } else {
        _showMessage(context, 'Not enough gems for ${item.name}');
      }
      return;
    }

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
        } else if (item.type == ShopItemType.adRemoval) {
          await gameService.markAdsRemoved();
        }

        _showPurchasePopup(context, title: 'Purchased!', subtitle: item.name, emoji: item.icon);
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

  void _showPurchasePopup(BuildContext context, {required String title, required String subtitle, required String emoji}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Purchased',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, __) {
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack));
        final opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return Opacity(
          opacity: opacity.value,
          child: Center(
            child: _PurchasePopup(title: title, subtitle: subtitle, emoji: emoji),
          ),
        );
      },
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback? onPurchase;
  final bool isLocked;
  final String? lockLabel;

  const _ShopItemCard({
    required this.item,
    required this.onPurchase,
    this.isLocked = false,
    this.lockLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isSpecial = item.type == ShopItemType.special;
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
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            lockLabel ?? 'Locked',
                            style: context.textStyles.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isLocked) const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSpecial ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: isSpecial
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💎', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                '${item.gemCost ?? 0}',
                                style: context.textStyles.titleMedium?.bold.copyWith(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '\$${item.price.toStringAsFixed(2)}',
                            style: context.textStyles.titleMedium?.bold.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchasePopup extends StatefulWidget {
  const _PurchasePopup({required this.title, required this.subtitle, required this.emoji});
  final String title;
  final String subtitle;
  final String emoji;

  @override
  State<_PurchasePopup> createState() => _PurchasePopupState();
}

class _PurchasePopupState extends State<_PurchasePopup> with SingleTickerProviderStateMixin {
  final GlobalKey<ParticleFieldState> _particlesKey = GlobalKey<ParticleFieldState>();
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();

  @override
  void initState() {
    super.initState();
    // Haptics + audio
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<HapticsService>().successStrong();
      context.read<AudioService>().playSuccessSound();
      // Burst particles from center after build
      final box = context.findRenderObject() as RenderBox?;
      final size = box?.size ?? const Size(0, 0);
      _particlesKey.currentState?.burst(Offset(size.width / 2, size.height / 2), count: 48);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Particle overlay
        Positioned.fill(child: ParticleField(key: _particlesKey)),
        ScaleTransition(
          scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          child: Container(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [cs.surfaceContainerHighest, cs.surfaceContainerLow]),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 10),
                Text(widget.title, style: context.textStyles.titleLarge?.bold),
                const SizedBox(height: 6),
                Text(widget.subtitle, style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(shape: const StadiumBorder(), backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text('Awesome'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
