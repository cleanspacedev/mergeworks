import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/theme.dart';
import 'package:provider/provider.dart';
import 'package:mergeworks/models/game_item.dart';

class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameService>();
    final level = game.currentLevel;
    final discovered = game.discoveredTierCount;

    // Thresholds are defined in GameService so progression logic stays in sync.
    final startOfLevel = (level <= 1) ? 1 : (GameService.tierThresholdForLevel(level - 1) + 1); // inclusive
    final nextLevelRequired = GameService.tierThresholdForLevel(level) + 1; // first tier count that becomes next level
    final span = (nextLevelRequired - startOfLevel).clamp(1, 1 << 30);
    final current = (discovered - startOfLevel).clamp(0, span);
    final progress = (current / span).clamp(0.0, 1.0);
    final remaining = (nextLevelRequired - discovered).clamp(0, 1 << 30);

    final colors = AppLevelTheme.gradientForLevel(context, level);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Level'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: AppSpacing.paddingLg,
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LevelHeader(colors: colors, level: level),
                    const SizedBox(height: AppSpacing.lg),
                    _ProgressCard(
                      level: level,
                      progress: progress,
                      currentStep: current,
                      totalSteps: span,
                      remaining: remaining,
                      discovered: discovered,
                      nextLevelThreshold: nextLevelRequired,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.book),
                      onPressed: () => context.push('/collection'),
                      label: const Text('View Collection'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final List<Color> colors;
  final int level;
  const _LevelHeader({required this.colors, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.auto_awesome, size: 36, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level', style: Theme.of(context).textTheme.labelMedium?.withColor(Theme.of(context).colorScheme.onSurface)),
                Text('Level $level', style: Theme.of(context).textTheme.headlineLarge?.withColor(Theme.of(context).colorScheme.onSurface)),
                Text('Keep discovering new tiers to level up!', style: Theme.of(context).textTheme.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int level;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final int remaining;
  final int discovered;
  final int nextLevelThreshold;
  const _ProgressCard({
    required this.level,
    required this.progress,
    required this.currentStep,
    required this.totalSteps,
    required this.remaining,
    required this.discovered,
    required this.nextLevelThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final game = context.watch<GameService>();
    final stats = game.playerStats;
    // Suggest the next undiscovered tiers (emoji + tier label)
    final List<GameItem> all = game.getAllDiscoveredItems();
    final nextUndiscovered = all.where((i) => !i.isDiscovered).toList()
      ..sort((a, b) => a.tier.compareTo(b.tier));
    final int showCount = remaining.clamp(0, 6);
    final suggestions = nextUndiscovered.take(showCount).toList();
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: cs.primary),
                const SizedBox(width: 8),
                Text('Progress to Level ${level + 1}', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$currentStep of $totalSteps steps this level',
                    style: Theme.of(context).textTheme.labelMedium?.withColor(cs.onSurfaceVariant),
                  ),
                ),
                Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.labelMedium?.withColor(cs.onSurface)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.emoji_objects, color: cs.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remaining == 0
                        ? 'You\'re ready for Level ${level + 1}! Keep merging to discover new tiers.'
                        : 'Discover $remaining more ${remaining == 1 ? 'tier' : 'tiers'} to reach Level ${level + 1}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.collections_bookmark, label: '$discovered discovered'),
                _InfoChip(icon: Icons.flag, label: '$nextLevelThreshold needed for L${level + 1}'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Details', style: Theme.of(context).textTheme.titleMedium?.withColor(cs.onSurface)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(icon: Icons.stacked_bar_chart, label: 'This level span', value: '$totalSteps tiers'),
            _DetailRow(icon: Icons.check_circle, label: 'Discovered this level', value: '$currentStep tiers'),
            _DetailRow(icon: Icons.hourglass_bottom, label: 'Remaining to next level', value: '$remaining'),
            _DetailRow(icon: Icons.rocket_launch, label: 'Highest tier reached', value: 'Tier ${stats.highestTier}'),
            _DetailRow(icon: Icons.merge_type, label: 'Total merges', value: '${stats.totalMerges}'),
            const SizedBox(height: AppSpacing.md),
            if (suggestions.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('Next discoveries', style: Theme.of(context).textTheme.titleMedium?.withColor(cs.onSurface)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map((g) => _InfoChip(icon: Icons.star, label: '${g.emoji}  Tier ${g.tier}'))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.withColor(Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant))),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurface)),
        ],
      ),
    );
  }
}
