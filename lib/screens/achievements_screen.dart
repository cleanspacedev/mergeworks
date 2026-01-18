import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/achievement_service.dart';
import 'package:mergeworks/services/quest_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/models/achievement.dart';
import 'package:mergeworks/models/daily_quest.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/widgets/responsive_center.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Achievements & Quests'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Achievements', icon: Icon(Icons.emoji_events)),
              Tab(text: 'Daily Quests', icon: Icon(Icons.assignment)),
              Tab(text: 'Events', icon: Icon(Icons.local_fire_department)),
              Tab(text: 'Season', icon: Icon(Icons.auto_awesome)),
            ],
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _AchievementsTab(),
            _QuestsTab(),
            _EventQuestsTab(),
            _SeasonTab(),
          ],
        ),
      ),
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AchievementService>(
      builder: (context, service, child) {
        final achievements = service.achievements;
        final completed = achievements.where((a) => a.isCompleted).length;

        return ResponsiveCenter(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.zero,
                padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.tertiaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed',
                          style: context.textStyles.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '$completed / ${achievements.length}',
                          style: context.textStyles.headlineMedium?.bold.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: achievements.length,
                  itemBuilder: (context, index) => _AchievementCard(achievement: achievements[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: achievement.isCompleted
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: achievement.isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: context.textStyles.titleMedium?.bold.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (!achievement.isCompleted) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: achievement.progress,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${achievement.currentValue} / ${achievement.targetValue}',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed!',
                          style: context.textStyles.labelSmall?.bold.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              children: [
                Text(
                  '💎 ${achievement.rewardGems}',
                  style: context.textStyles.titleSmall?.bold.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestsTab extends StatelessWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestService>(
      builder: (context, service, child) {
        final quests = service.activeQuests;

        if (quests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No active quests',
                  style: context.textStyles.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ResponsiveCenter(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: quests.length,
            itemBuilder: (context, index) => _QuestCard(quest: quests[index]),
          ),
        );
      },
    );
  }
}

class _EventQuestsTab extends StatelessWidget {
  const _EventQuestsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestService>(
      builder: (context, service, child) {
        final quests = service.activeEventQuests;
        if (quests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, size: 80, color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5)),
                const SizedBox(height: AppSpacing.md),
                Text('No active events', style: context.textStyles.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text('Check back next week!', style: context.textStyles.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          );
        }

        return ResponsiveCenter(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: quests.length,
            itemBuilder: (context, index) => _QuestCard(quest: quests[index]),
          ),
        );
      },
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<GameService>(
      builder: (context, gs, child) {
        final stats = gs.playerStats;
        final cs = Theme.of(context).colorScheme;

        int xpNeededForNext(int level) {
          final l = level.clamp(1, 999);
          if (l <= 5) return 60 + l * 20;
          return 160 + (l - 5) * 35;
        }

        final needed = xpNeededForNext(stats.seasonLevel);
        final progress = needed <= 0 ? 0.0 : (stats.seasonXp / needed).clamp(0.0, 1.0);

        return ResponsiveCenter(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primaryContainer, cs.tertiaryContainer]),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Season Track', style: context.textStyles.titleLarge?.bold.copyWith(color: cs.onPrimaryContainer))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: Text('Lv ${stats.seasonLevel}', style: context.textStyles.labelLarge?.bold.copyWith(color: cs.onPrimaryContainer)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${stats.seasonXp} / $needed XP', style: context.textStyles.labelMedium?.withColor(cs.onPrimaryContainer.withValues(alpha: 0.9))),
                  const SizedBox(height: 4),
                  Text('Earn XP from merges and quests. Level-ups grant coins (and gems every 5 levels).', style: context.textStyles.bodySmall?.withColor(cs.onPrimaryContainer.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, color: cs.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Item Mastery', style: context.textStyles.titleMedium?.bold.withColor(cs.onSurface)),
                        const SizedBox(height: 2),
                        Text('Level ${stats.masteryLevel} • +${((stats.masteryLevel - 1).clamp(0, 50))}% coins', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home_work_outlined, color: cs.tertiary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Town Upgrades', style: context.textStyles.titleMedium?.bold.withColor(cs.onSurface))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Coin bonus: Lv ${stats.townCoinBonusLevel}  •  Energy cap: Lv ${stats.townEnergyCapLevel}', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text('Upgrade these in the Shop using coins.', style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant)),
                ],
              ),
            ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  final DailyQuest quest;

  const _QuestCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    final timeRemaining = quest.expiresAt.difference(DateTime.now());
    final hoursLeft = timeRemaining.inHours;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: quest.isCompleted
          ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quest.title,
                    style: context.textStyles.titleMedium?.bold.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!quest.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${hoursLeft}h left',
                      style: context.textStyles.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              quest.description,
              style: context.textStyles.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!quest.isCompleted) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: quest.progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${quest.currentValue} / ${quest.targetValue}',
                    style: context.textStyles.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '💎 ${quest.rewardGems}',
                        style: context.textStyles.labelSmall?.bold,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '🪙 ${quest.rewardCoins}',
                        style: context.textStyles.labelSmall?.bold,
                      ),
                    ],
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Quest Completed!',
                    style: context.textStyles.titleSmall?.bold.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
