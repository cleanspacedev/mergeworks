import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/theme.dart';

/// Bottom sheet prompting the player to spend gems to reveal a hint.
///
/// Returns `true` from the sheet if the user confirms the purchase.
class HintOfferSheet extends StatelessWidget {
  final int costGems;
  final bool canAfford;
  final int currentGems;

  const HintOfferSheet({
    super.key,
    required this.costGems,
    required this.canAfford,
    required this.currentGems,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Icon(Icons.lightbulb, color: cs.onSecondaryContainer),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need a hint?', style: context.textStyles.titleLarge?.bold),
                        const SizedBox(height: 4),
                        Text(
                          'We can highlight a merge for you for $costGems gems 💎',
                          style: context.textStyles.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(false),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.diamond_outlined, color: cs.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You have $currentGems gems',
                        style: context.textStyles.bodyMedium?.medium,
                      ),
                    ),
                    Text(
                      '-$costGems',
                      style: context.textStyles.bodyMedium?.bold.copyWith(color: canAfford ? cs.onSurface : cs.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: Text('Not now', style: context.textStyles.titleMedium?.bold),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canAfford ? () => context.pop(true) : null,
                      icon: Icon(Icons.auto_awesome, color: cs.onPrimary),
                      label: Text(
                        'Reveal ($costGems 💎)',
                        style: context.textStyles.titleMedium?.bold.copyWith(color: cs.onPrimary),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
