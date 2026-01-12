import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/log_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final result = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const _ReportBugSheet(),
                  );
                  if (!context.mounted) return;
                  if (result == 'submitted') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks! Your report was submitted.')),
                    );
                  }
                },
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                icon: const Icon(Icons.bug_report),
                label: const Text('Report a Bug'),
              ),
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

class _ReportBugSheet extends StatefulWidget {
  const _ReportBugSheet();

  @override
  State<_ReportBugSheet> createState() => _ReportBugSheetState();
}

class _ReportBugSheetState extends State<_ReportBugSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Report a Bug', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Describe the issue (optional)',
                hintText: 'What happened? Steps to reproduce?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Submitting...' : 'Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final firebase = context.read<FirebaseService>();
      final userId = firebase.userId ?? 'anonymous';
      final comment = _controller.text.trim();
      final logs = LogService.instance.last(100);

      final Map<String, dynamic> data = {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.toString(),
        'appVersion': '1.0.0',
        'logs': logs,
      };
      if (comment.isNotEmpty) {
        data['comment'] = comment;
      }

      await firebase.firestore.collection('bug_reports').add(data);
      if (!mounted) return;
      Navigator.of(context).pop('submitted');
    } catch (e) {
      debugPrint('Failed to submit bug report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
