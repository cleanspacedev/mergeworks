import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/theme.dart';

class NoMovesOfferSheet extends StatelessWidget {
  final int summonCount;
  final int discountedCost;
  final int originalCost;
  final int currentCoins;
  final bool canSummon;
  final bool canAfford;

  const NoMovesOfferSheet({
    super.key,
    required this.summonCount,
    required this.discountedCost,
    required this.originalCost,
    required this.currentCoins,
    required this.canSummon,
    required this.canAfford,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;
    final card = cs.surfaceContainerHighest;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.block, color: cs.error, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No moves left',
                        style: context.textStyles.titleMedium?.semiBold.withColor(onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => context.pop(false),
                      icon: Icon(Icons.close, color: onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'You’re stuck — there are no mergeable groups on the board. Summon a few low-tier items to open up new combos.',
                  style: context.textStyles.bodyMedium?.withColor(onSurface.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_motion, color: cs.tertiary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Summon x$summonCount (50% off)',
                          style: context.textStyles.titleSmall?.semiBold.withColor(onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          '$discountedCost → $originalCost',
                          style: context.textStyles.labelMedium?.semiBold.withColor(cs.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Coins: $currentCoins',
                  style: context.textStyles.labelLarge?.withColor(onSurface.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: (canSummon && canAfford) ? () => context.pop(true) : null,
                  icon: Icon(Icons.auto_awesome_motion, color: cs.onTertiary),
                  label: Text(
                    canSummon
                        ? (canAfford ? 'Summon for $discountedCost' : 'Not enough coins')
                        : 'Board is full',
                    style: context.textStyles.titleSmall?.semiBold.withColor(cs.onTertiary),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: cs.tertiary),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.pop(false),
                  style: OutlinedButton.styleFrom(foregroundColor: onSurface),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
