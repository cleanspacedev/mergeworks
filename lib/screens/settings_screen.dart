import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer2<AudioService, GameService>(builder: (context, audioService, gameService, child) {
        return ListView(
          padding: AppSpacing.paddingMd,
          children: [
            _buildSection(
              context,
              'Audio Settings 🔊',
              [
                _SettingsTile(
                  icon: Icons.volume_up,
                  title: 'Sound Effects',
                  subtitle: audioService.soundEnabled ? 'On' : 'Off',
                  trailing: Switch(
                    value: audioService.soundEnabled,
                    onChanged: (_) => audioService.toggleSound(),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.music_note,
                  title: 'Music',
                  subtitle: audioService.musicEnabled ? 'On' : 'Off',
                  trailing: Switch(
                    value: audioService.musicEnabled,
                    onChanged: (_) => audioService.toggleMusic(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              context,
              'Game Stats 📊',
              [
                _SettingsTile(
                  icon: Icons.auto_awesome,
                  title: 'Total Merges',
                  subtitle: '${gameService.playerStats.totalMerges}',
                ),
                _SettingsTile(
                  icon: Icons.trending_up,
                  title: 'Highest Tier',
                  subtitle: 'Tier ${gameService.playerStats.highestTier}',
                ),
                _SettingsTile(
                  icon: Icons.local_fire_department,
                  title: 'Login Streak',
                  subtitle: '${gameService.playerStats.loginStreak} days',
                ),
                _SettingsTile(
                  icon: Icons.collections,
                  title: 'Items Discovered',
                  subtitle: '${gameService.playerStats.discoveredItems.length} / 18',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              context,
              'About 📱',
              [
                _SettingsTile(
                  icon: Icons.info,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
                _SettingsTile(
                  icon: Icons.code,
                  title: 'Built with',
                  subtitle: 'Flutter & Dreamflow',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSection(
              context,
              'Diagnostics 🧪',
              [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final svc = context.read<FirebaseService>();
                      final result = await svc.callTestPing(name: 'settings');
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cloud Function Result'),
                          content: Text(result),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
                        ),
                      );
                    },
                    icon: const Icon(Icons.cloud_sync),
                    label: const Text('Test Cloud Function (ping)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.tonalIcon(
              onPressed: () => _showResetDialog(context),
              icon: const Icon(Icons.refresh, color: Colors.red),
              label: const Text('Reset Game Progress', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: context.textStyles.titleMedium?.bold.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Game Progress?'),
        content: const Text('This will delete all your progress, items, and purchases. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game reset! Restart the app to see changes.')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: context.textStyles.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: context.textStyles.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
    );
  }
}
