import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/theme.dart';

class NoSummonsOfferSheet extends StatelessWidget {
  final int discountedCost;
  final int originalCost;
  final int currentCoins;
  final bool canAfford;

  const NoSummonsOfferSheet({
    super.key,
    required this.discountedCost,
    required this.originalCost,
    required this.currentCoins,
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
                    Icon(Icons.auto_fix_high, color: cs.secondary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No space to summon',
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
                  'Your board is full, so summoning can\'t add new items. Shuffling can rearrange the board and create new merge paths.',
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
                      Icon(Icons.shuffle, color: cs.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Shuffle (50% off)',
                          style: context.textStyles.titleSmall?.semiBold.withColor(onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(
                          '$discountedCost → $originalCost',
                          style: context.textStyles.labelMedium?.semiBold.withColor(cs.onSecondaryContainer),
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
                  onPressed: canAfford ? () => context.pop(true) : null,
                  icon: Icon(Icons.shuffle, color: cs.onSecondary),
                  label: Text(
                    canAfford ? 'Shuffle for $discountedCost' : 'Not enough coins',
                    style: context.textStyles.titleSmall?.semiBold.withColor(cs.onSecondary),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: cs.secondary),
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
