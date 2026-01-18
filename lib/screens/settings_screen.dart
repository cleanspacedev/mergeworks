import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/log_service.dart';
import 'package:mergeworks/services/bug_report_service.dart';
import 'package:flutter/foundation.dart';
import 'package:mergeworks/services/accessibility_service.dart';
import 'package:mergeworks/services/game_platform_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:mergeworks/services/popup_manager.dart';
import 'package:mergeworks/widgets/responsive_center.dart';

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
      body: Consumer3<AudioService, GameService, AccessibilityService>(builder: (context, audioService, gameService, a11y, child) {
        return ResponsiveCenter(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
            // Move Game Stats to the top
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
            // Move platform buttons directly under Game Stats
            Builder(builder: (context) {
              final platform = context.watch<GamePlatformService>();
              if (!platform.isAvailable) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: platform.signedIn ? () => context.read<GamePlatformService>().showLeaderboards() : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('Global Leaderboards'),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            Builder(builder: (context) {
              final platform = context.watch<GamePlatformService>();
              if (!platform.isAvailable) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: platform.signedIn ? () => context.read<GamePlatformService>().showAchievements() : null,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Platform Achievements'),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            Builder(builder: (context) {
              final platform = context.watch<GamePlatformService>();
              if (!platform.isAvailable || platform.signedIn) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.read<GamePlatformService>().initialize(),
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  icon: const Icon(Icons.videogame_asset),
                  label: const Text('Sign in to Game Center'),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),

            // Moved Audio above Accessibility
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 16),
                          const SizedBox(width: 6),
                          Text('SFX Volume (${(audioService.sfxVolume * 100).round()}%)', style: context.textStyles.labelMedium),
                        ],
                      ),
                      Slider(
                        value: audioService.sfxVolume,
                        onChanged: audioService.soundEnabled ? (v) => audioService.setSfxVolume(v) : null,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '${(audioService.sfxVolume * 100).round()}%'.toString(),
                      ),
                    ],
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 16),
                          const SizedBox(width: 6),
                          Text('Music Volume (${(audioService.musicVolume * 100).round()}%)', style: context.textStyles.labelMedium),
                        ],
                      ),
                      Slider(
                        value: audioService.musicVolume,
                        onChanged: audioService.musicEnabled ? (v) => audioService.setMusicVolume(v) : null,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label: '${(audioService.musicVolume * 100).round()}%'.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Accessibility now comes after Audio
            _buildSection(
              context,
              'Accessibility ♿',
              [
                _SettingsTile(
                  icon: Icons.record_voice_over,
                  title: 'VoiceOver',
                  subtitle: a11y.voiceOverHints ? 'On' : 'Off',
                  trailing: Switch(value: a11y.voiceOverHints, onChanged: a11y.setVoiceOverHints),
                ),
                _SettingsTile(
                  icon: Icons.mic,
                  title: 'Voice Control',
                  subtitle: a11y.voiceControlHints ? 'On' : 'Off',
                  trailing: Switch(value: a11y.voiceControlHints, onChanged: a11y.setVoiceControlHints),
                ),
                _SettingsTile(
                  icon: Icons.format_size,
                  title: 'Larger Text',
                  subtitle: a11y.largerText ? '200%' : '100%',
                  trailing: Switch(value: a11y.largerText, onChanged: a11y.setLargerText),
                ),
                _SettingsTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Interface',
                  subtitle: a11y.forceDark ? 'On' : 'Off',
                  trailing: Switch(value: a11y.forceDark, onChanged: a11y.setForceDark),
                ),
                _SettingsTile(
                  icon: Icons.texture,
                  title: 'Differentiate Without Color Alone',
                  subtitle: a11y.differentiateWithoutColor ? 'On' : 'Off',
                  trailing: Switch(value: a11y.differentiateWithoutColor, onChanged: a11y.setDifferentiateWithoutColor),
                ),
                _SettingsTile(
                  icon: Icons.contrast,
                  title: 'Sufficient Contrast',
                  subtitle: a11y.highContrast ? 'High' : 'Standard',
                  trailing: Switch(value: a11y.highContrast, onChanged: a11y.setHighContrast),
                ),
                _SettingsTile(
                  icon: Icons.motion_photos_off,
                  title: 'Reduced Motion',
                  subtitle: a11y.reducedMotion ? 'On' : 'Off',
                  trailing: Switch(value: a11y.reducedMotion, onChanged: a11y.setReducedMotion),
                ),
                _SettingsTile(
                  icon: Icons.closed_caption,
                  title: 'Captions',
                  subtitle: a11y.captionsEnabled ? 'On' : 'Off',
                  trailing: Switch(value: a11y.captionsEnabled, onChanged: a11y.setCaptionsEnabled),
                ),
                _SettingsTile(
                  icon: Icons.description,
                  title: 'Audio Descriptions',
                  subtitle: a11y.audioDescriptions ? 'On' : 'Off',
                  trailing: Switch(value: a11y.audioDescriptions, onChanged: a11y.setAudioDescriptions),
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
                  final result = await context.read<PopupManager>().showBottomSheet<String>(
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
          ),
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
    unawaited(
      context.read<PopupManager>().showAppDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reset Game Progress?'),
              content: const Text('This will delete all your progress, items, and purchases. This action cannot be undone.'),
              actions: [
                TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Game reset! Restart the app to see changes.')),
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Reset'),
                ),
              ],
            ),
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
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                  onPressed: _submitting ? null : () => context.pop(),
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
      // Ensure we have an authenticated user (anonymous is fine)
      String? userId = firebase.userId;
      if (userId == null) {
        await firebase.signInAnonymously();
        userId = firebase.userId;
      }
      userId ??= 'anonymous';
      final comment = _controller.text.trim();

      // Submit via centralized service (writes both user-scoped and central docs)
      final bugService = context.read<BugReportService>();
      final id = await bugService.submitBugReport(
        title: 'User bug report',
        description: comment.isEmpty ? '(no description)' : comment,
        extras: {
          'source': 'settings',
          'appVersion': '1.0.0',
          'platform': defaultTargetPlatform.toString(),
        },
      );

      if (!mounted) return;
      if (id != null) {
        context.pop('submitted');
      } else {
        // Fall back: allow user to copy the prepared report to clipboard for emailing
        final fallback = <String, dynamic>{
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
          'platform': defaultTargetPlatform.toString(),
          'appVersion': '1.0.0',
          'comment': comment,
          'logs': LogService.instance.last(100),
        };
        final text = const JsonEncoder.withIndent('  ').convert(fallback);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit. Please try again.'),
            action: SnackBarAction(
              label: 'Copy Report',
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to submit bug report: $e');
      if (!mounted) return;
      final fallback = <String, dynamic>{
        'userId': context.read<FirebaseService>().userId ?? 'anonymous',
        'createdAt': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.toString(),
        'appVersion': '1.0.0',
        'comment': _controller.text.trim(),
        'logs': LogService.instance.last(100),
        'error': e.toString(),
      };
      final text = const JsonEncoder.withIndent('  ').convert(fallback);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit. Please try again.'),
          action: SnackBarAction(
            label: 'Copy Report',
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          ),
        ),
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
