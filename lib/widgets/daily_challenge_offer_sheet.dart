import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/nav.dart';
import 'package:mergeworks/theme.dart';

class DailyChallengeOfferSheet extends StatelessWidget {
  const DailyChallengeOfferSheet({super.key, required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final card = cs.surfaceContainerHighest;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome, color: cs.onPrimary, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Challenge', style: context.textStyles.titleLarge?.semiBold),
                        const SizedBox(height: 4),
                        Text(
                          isCompleted ? 'Already cleared today — nice work.' : 'Clear the board with today\'s seeded puzzle.',
                          style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: isCompleted
                  ? null
                  : () {
                      context.pop();
                      context.push(AppRoutes.dailyChallenge);
                    },
              icon: Icon(Icons.play_arrow, color: cs.onPrimary),
              label: Text('Start today\'s run', style: context.textStyles.titleSmall?.semiBold?.withColor(cs.onPrimary)),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              child: Text('Not now', style: context.textStyles.titleSmall?.semiBold?.withColor(cs.onSurface)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
