import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/widgets/unique_item_glyph.dart';
import 'package:mergeworks/services/popup_manager.dart';

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
                      item: item,
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
  final GameItem item;

  const _CollectionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: item.isDiscovered 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: item.isDiscovered ? () => _showDetails(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingSm,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              item.isDiscovered
                  ? UniqueItemGlyph(item: item, size: 48)
                  : const Icon(Icons.lock, size: 44, color: Colors.grey),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.isDiscovered ? item.name : '???',
                style: context.textStyles.titleSmall?.bold.copyWith(
                  color: item.isDiscovered 
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Tier ${item.tier}',
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
    unawaited(
      context.read<PopupManager>().showBottomSheet<void>(
            context: context,
            builder: (context) => Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UniqueItemGlyph(item: item, size: 80),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    item.name,
                    style: context.textStyles.headlineMedium?.bold.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      'Tier ${item.tier}',
                      style: context.textStyles.labelLarge?.bold.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    item.isDiscovered ? item.description : 'Not yet discovered',
                    style: context.textStyles.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
    );
  }
}
