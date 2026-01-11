import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/theme.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Book'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<GameService>(
        builder: (context, gameService, child) {
          final items = gameService.getAllDiscoveredItems();
          final discovered = items.where((item) => item.isDiscovered).length;

          return Column(
            children: [
              Container(
                margin: AppSpacing.paddingMd,
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: context.textStyles.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$discovered / ${items.length} Items',
                            style: context.textStyles.headlineSmall?.bold.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: discovered / items.length,
                              minHeight: 8,
                              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: AppSpacing.paddingMd,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _CollectionCard(
                      emoji: item.isDiscovered ? item.emoji : '🔒',
                      name: item.isDiscovered ? item.name : '???',
                      tier: item.tier,
                      description: item.isDiscovered ? item.description : 'Not yet discovered',
                      isDiscovered: item.isDiscovered,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final String emoji;
  final String name;
  final int tier;
  final String description;
  final bool isDiscovered;

  const _CollectionCard({
    required this.emoji,
    required this.name,
    required this.tier,
    required this.description,
    required this.isDiscovered,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDiscovered 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: isDiscovered ? () => _showDetails(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingSm,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: 48,
                  color: isDiscovered ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name,
                style: context.textStyles.titleSmall?.bold.copyWith(
                  color: isDiscovered 
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Tier $tier',
                style: context.textStyles.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: AppSpacing.md),
            Text(
              name,
              style: context.textStyles.headlineMedium?.bold.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(
                'Tier $tier',
                style: context.textStyles.labelLarge?.bold.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              description,
              style: context.textStyles.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
