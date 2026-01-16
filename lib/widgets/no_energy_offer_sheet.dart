import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/theme.dart';

/// Bottom sheet shown when the player is blocked by **zero energy**.
///
/// Returns `true` if the player confirms the “buy energy” action.
class NoEnergyOfferSheet extends StatelessWidget {
  final int energyPackAmount;
  final int currentEnergy;
  final int requiredEnergy;
  final String? priceLabel;
  final bool purchaseEnabled;

  const NoEnergyOfferSheet({
    super.key,
    required this.energyPackAmount,
    required this.currentEnergy,
    required this.requiredEnergy,
    required this.priceLabel,
    required this.purchaseEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    final effectiveLabel = priceLabel ?? 'Buy';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(Icons.bolt, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Out of energy', style: context.textStyles.titleLarge?.bold.withColor(onSurface)),
                          const SizedBox(height: 4),
                          Text(
                            requiredEnergy <= 1
                                ? 'Merges cost energy. Grab a quick refill to keep playing.'
                                : 'You need at least $requiredEnergy energy to make a move. You currently have $currentEnergy.',
                            style: context.textStyles.bodyMedium?.withColor(onSurface.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.pop(false),
                      icon: Icon(Icons.close, color: onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flash_on, color: cs.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '+$energyPackAmount Energy',
                          style: context.textStyles.titleMedium?.semiBold.withColor(onSurface),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          effectiveLabel,
                          style: context.textStyles.labelLarge?.semiBold.withColor(cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: purchaseEnabled ? () => context.pop(true) : null,
                  icon: Icon(Icons.shopping_bag, color: cs.onPrimary),
                  label: Text(
                    'Buy $energyPackAmount Energy',
                    style: context.textStyles.titleMedium?.bold.withColor(cs.onPrimary),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurface,
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Maybe later', style: context.textStyles.titleMedium?.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
