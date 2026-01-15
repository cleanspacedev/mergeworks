import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/achievement_service.dart';
import 'package:mergeworks/services/quest_service.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/widgets/energy_bar.dart';
import 'package:mergeworks/widgets/currency_display.dart';
import 'package:mergeworks/widgets/grid_item_widget.dart';
import 'package:mergeworks/widgets/tutorial_overlay.dart';
import 'package:mergeworks/widgets/particle_field.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/accessibility_service.dart';
import 'package:mergeworks/services/haptics_service.dart';

class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({super.key});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  GameItem? _selectedItem;
  final Set<String> _highlightedItems = {};
  final Set<String> _animatingIds = {};
  int _invalidMergeAttempts = 0; // Tracks wrong selections to throttle messaging
  OverlayEntry? _activeCenterPopup; // Tracks the currently visible center popup
  bool _placingWildcard = false; // When true, tapping an empty cell places a wildcard

  // Particle and measurement helpers
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey<ParticleFieldState> _particleKey = GlobalKey<ParticleFieldState>();

  // Merge animation state
  AnimationController? _mergeController;
  List<_Ghost> _ghosts = [];
  Offset? _targetCenter;

  // Spawn animation state (reverse of merge)
  AnimationController? _spawnController;
  List<_SpawnGhost> _spawnGhosts = [];
  Offset? _spawnOrigin;

  // Celebration pulse state
  AnimationController? _pulseController;
  Offset? _pulseCenter;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _mergeController?.dispose();
    _spawnController?.dispose();
    _pulseController?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // Helper to safely trigger rebuilds from extension methods without using the
  // protected setState outside of this State subclass.
  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _onItemTap(GameItem item, GameService gameService) {
    // Ensure BG music can start on platforms that require a user gesture (e.g., Web)
    context.read<AudioService>().maybeStartMusicFromUserGesture();
    setState(() {
      // Toggle off if already selected
      if (_highlightedItems.contains(item.id)) {
        _highlightedItems.remove(item.id);
        // Maintain a valid _selectedItem for abilities
        if (_highlightedItems.isEmpty) {
          _selectedItem = null;
        } else {
          final fallback = gameService.gridItems.where((gi) => _highlightedItems.contains(gi.id)).firstOrNull;
          _selectedItem = fallback;
          // Ensure remaining selection stays as a single connected group
          _pruneSelectionToConnected(gameService);
        }
        // Tap feedback
        context.read<AudioService>().playClickSound();
        return;
      }

      // If nothing selected yet, start a new selection with this item
      if (_highlightedItems.isEmpty) {
        _highlightedItems.add(item.id);
        _selectedItem = item; // anchor for abilities like duplicate/clear
        _invalidMergeAttempts = 0;
        context.read<AudioService>().playClickSound();
        return;
      }

      // Enforce same tier across the current selection, but allow wildcards to join any selection
      final selectedItems = gameService.gridItems.where((gi) => _highlightedItems.contains(gi.id)).toList();
      final nonWildSelected = selectedItems.where((gi) => !gi.isWildcard).toList();
      final hasWildcardInSelection = selectedItems.any((gi) => gi.isWildcard);
      final nonWildTiers = nonWildSelected.map((e) => e.tier).toSet();

      bool tierCompatible;
      if (item.isWildcard) {
        tierCompatible = true;
      } else if (nonWildTiers.isEmpty) {
        // Only wildcards selected so far -> any tier can start the base
        tierCompatible = true;
      } else if (nonWildTiers.length == 1 && nonWildTiers.first == item.tier) {
        tierCompatible = true;
      } else if (hasWildcardInSelection && nonWildTiers.length == 1 && nonWildTiers.first == item.tier) {
        tierCompatible = true;
      } else {
        tierCompatible = false;
      }

      if (!tierCompatible) {
        // Reset selection to this new tier to keep UX predictable
        _highlightedItems
          ..clear()
          ..add(item.id);
        _selectedItem = item;
        _invalidMergeAttempts = 0;
        context.read<AudioService>().playClickSound();
        return;
      }

      // Enforce connectivity: new item must be adjacent to at least one currently selected tile
      if (!_isConnectedToSelection(item, gameService)) {
        _showCenterPopup('Selections must be adjacent', icon: Icons.link_off);
        return;
      }

      // Same tier (or wildcard) and connected -> add to selection
      _highlightedItems.add(item.id);
      _selectedItem = item; // last tapped becomes primary for single-item abilities
      _invalidMergeAttempts = 0;
      context.read<AudioService>().playClickSound();
    });
  }

  void _onItemLongPress(GameItem item, GameService gameService) {
    context.read<AudioService>().maybeStartMusicFromUserGesture();
    final count = gameService.playerStats.autoSelectCount;
    if (count <= 0) {
      _showCenterPopup('Unlock Auto-Select in the Shop (💎)');
      return;
    }
    if (item.gridX == null || item.gridY == null) return;

    // Determine base tier for selection
    int? baseTier;
    if (item.isWildcard) {
      // If anchor is a wildcard, choose the nearest non-wild item as the base
      final nonWild = gameService.gridItems.where((gi) => gi.gridX != null && gi.gridY != null && !gi.isWildcard).toList();
      if (nonWild.isEmpty) {
        _showCenterPopup('No base item near wildcard');
        return;
      }
      int distSq(GameItem a) {
        final dx = (a.gridX! - item.gridX!);
        final dy = (a.gridY! - item.gridY!);
        return dx * dx + dy * dy;
      }
      nonWild.sort((a, b) => distSq(a).compareTo(distSq(b)));
      baseTier = nonWild.first.tier;
    } else {
      baseTier = item.tier;
    }

    // BFS over 8-directionally adjacent tiles; include only base-tier or wildcards
    final Set<String> picked = {item.id};
    final List<GameItem> queue = [item];

    int anchorX = item.gridX!;
    int anchorY = item.gridY!;

    bool isEligible(GameItem gi) => gi.gridX != null && gi.gridY != null && (gi.isWildcard || gi.tier == baseTier);
    int distSqFromAnchor(GameItem a) {
      final dx = (a.gridX! - anchorX);
      final dy = (a.gridY! - anchorY);
      return dx * dx + dy * dy;
    }

    while (queue.isNotEmpty && picked.length < count) {
      final current = queue.removeAt(0);
      // Find neighbors by scanning board (grid is small; fine for now)
      final neighbors = gameService.gridItems
          .where((gi) => gi.id != current.id && isEligible(gi) && _areAdjacent8(current, gi) && !picked.contains(gi.id))
          .toList();
      // Prefer closer to the anchor to keep the cluster "closest"
      neighbors.sort((a, b) => distSqFromAnchor(a).compareTo(distSqFromAnchor(b)));
      for (final n in neighbors) {
        if (picked.length >= count) break;
        picked.add(n.id);
        queue.add(n);
      }
    }

    // Keep the valid connected group even if it cannot merge yet
    final minNeeded = gameService.powerMergeCharges > 0 ? 2 : 3;

    setState(() {
      _highlightedItems
        ..clear()
        ..addAll(picked);
      _selectedItem = item;
      _invalidMergeAttempts = 0;
    });

    // Feedback
    context.read<AudioService>().playClickSound();
    context.read<HapticsService>().successSoft();

    // Attempt auto-merge if valid
    final itemsToMerge = gameService.gridItems.where((gi) => picked.contains(gi.id)).toList();
    final canAutoMerge = picked.length >= minNeeded && gameService.canMerge(itemsToMerge);
    if (canAutoMerge) {
      // Use same merge flow as the Merge button
      unawaited(_performMerge(
        gameService,
        context.read<AudioService>(),
        context.read<AchievementService>(),
        context.read<QuestService>(),
        context.read<HapticsService>(),
      ));
      return; // Skip the "Auto-selected" hint to avoid double messaging
    }

    if (picked.length < minNeeded) {
      _showCenterPopup('Need $minNeeded or more to merge');
    } else {
      _showCenterPopup('Auto-selected ${picked.length}');
    }
  }

  // Returns true if candidate is orthogonally adjacent to any currently selected item
  bool _isConnectedToSelection(GameItem candidate, GameService gs) {
    if (candidate.gridX == null || candidate.gridY == null) return false;
    final selected = gs.gridItems.where((gi) => _highlightedItems.contains(gi.id)).toList();
    for (final s in selected) {
      if (s.gridX == null || s.gridY == null) continue;
      if (_areAdjacent8(s, candidate)) return true;
    }
    return false;
  }

  // Orthogonal adjacency only (no diagonals)

  // 8-directional adjacency (includes diagonals)
  bool _areAdjacent8(GameItem a, GameItem b) {
    final ax = a.gridX, ay = a.gridY, bx = b.gridX, by = b.gridY;
    if (ax == null || ay == null || bx == null || by == null) return false;
    final dx = (ax - bx).abs();
    final dy = (ay - by).abs();
    return (dx <= 1 && dy <= 1) && !(dx == 0 && dy == 0);
  }

  // If current selection becomes disconnected (e.g., after removing a bridge),
  // keep only the connected component anchored at _selectedItem (or any selected item if null)
  void _pruneSelectionToConnected(GameService gs) {
    if (_highlightedItems.isEmpty) return;
    final idToItem = {for (final i in gs.gridItems) i.id: i};
    String anchorId = _selectedItem != null && _highlightedItems.contains(_selectedItem!.id)
        ? _selectedItem!.id
        : _highlightedItems.first;

    // BFS over selected items using 8-direction adjacency
    final Set<String> visited = {};
    final List<String> queue = [];
    queue.add(anchorId);
    visited.add(anchorId);
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentItem = idToItem[current];
      if (currentItem == null) continue;
      for (final otherId in _highlightedItems) {
        if (visited.contains(otherId)) continue;
        final otherItem = idToItem[otherId];
        if (otherItem == null) continue;
        if (_areAdjacent8(currentItem, otherItem)) {
          visited.add(otherId);
          queue.add(otherId);
        }
      }
    }

    if (visited.length != _highlightedItems.length) {
      _highlightedItems
        ..clear()
        ..addAll(visited);
      // Ensure _selectedItem remains valid
      _selectedItem = idToItem[anchorId];
    }
  }

  Future<void> _performMerge(GameService gameService, AudioService audioService, AchievementService achievementService, QuestService questService, HapticsService haptics) async {
    if (_selectedItem == null) return;

    final itemsToMerge = gameService.gridItems.where((item) => _highlightedItems.contains(item.id)).toList();

    if (gameService.playerStats.energy <= 0) {
      _showMessage('Not enough energy ⚡');
      return;
    }
    
    if (!gameService.canMerge(itemsToMerge)) {
      _handleInvalidMergeAttempt();
      return;
    }

    // Play advanced merge animation before mutating state
    await _playMergeAnimation(itemsToMerge);
    final prevLevel = gameService.currentLevel;
    final newItem = await gameService.mergeItems(itemsToMerge);
    if (newItem != null) {
      // Haptics first so it lands with the visual
      unawaited(haptics.onMerge(selectionCount: itemsToMerge.length, resultingTier: newItem.tier));
      setState(() {
        _selectedItem = null;
        _highlightedItems.clear();
        _invalidMergeAttempts = 0; // reset on successful merge
      });

      // Tuned SFX and celebrations
      final reducedMotion = context.read<AccessibilityService>().reducedMotion;
      unawaited(audioService.playMergeSoundTuned(tier: newItem.tier, selectionCount: itemsToMerge.length));
      if (!reducedMotion) {
        _confettiController.play();
      }
      // Emit local particle burst at target (scaled by tier, reduced for low-motion)
      final center = _targetCenter;
      if (center != null) {
        final int base = reducedMotion ? 10 : 24;
        final int perTier = reducedMotion ? 2 : 6;
        final int count = (base + newItem.tier * perTier).clamp(10, 160);
        _particleKey.currentState?.burst(center, count: count);
        _triggerScreenPulse(center: center, tier: newItem.tier, reducedMotion: reducedMotion);
        _showComboBanner(tier: newItem.tier, selectionCount: itemsToMerge.length);
      }
      _showMessage('Merged into ${newItem.name}! 🎉');

      // Level up ding
      final currLevel = gameService.currentLevel;
      if (currLevel > prevLevel) {
        unawaited(audioService.playLevelUp());
      }

      final completedAchievements = await achievementService.checkProgress(gameService.playerStats);
      for (final achievement in completedAchievements) {
        await gameService.addGems(achievement.rewardGems);
        _showMessage('Achievement unlocked: ${achievement.title}! +${achievement.rewardGems} gems 💎');
      }

      final completedQuests = await questService.checkProgress(gameService.playerStats);
      for (final quest in completedQuests) {
        await gameService.addGems(quest.rewardGems);
        await gameService.addCoins(quest.rewardCoins);
        _showMessage('Quest completed: ${quest.title}! 🎯');
      }
    }
  }

  void _handleInvalidMergeAttempt() {
    if (!mounted) return;
    _invalidMergeAttempts++;
    // Show on first wrong attempt, then every 20th wrong attempt
    if (_invalidMergeAttempts == 1 || _invalidMergeAttempts % 20 == 0) {
      _showMergeRequirementMessage();
    }
  }

  void _showMergeRequirementMessage() {
    if (!mounted) return;
    _showCenterPopup('Need 3 or more to merge', icon: Icons.info_outline);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    _showCenterPopup(message, icon: Icons.auto_awesome);
  }

  void _showCenterPopup(String message, {IconData? icon, Duration duration = const Duration(milliseconds: 1600)}) {
    try {
      // Remove any existing popup to avoid stacking
      _activeCenterPopup?.remove();
      _activeCenterPopup = null;

      final overlay = Overlay.of(context);

      final Color bg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95);
      final Color border = Theme.of(context).colorScheme.outline.withValues(alpha: 0.25);
      final Color onBg = Theme.of(context).colorScheme.onSurface;

      late AnimationController controller;
      late CurvedAnimation curve;

      controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), reverseDuration: const Duration(milliseconds: 140));
      curve = CurvedAnimation(parent: controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);

      final entry = OverlayEntry(
        builder: (ctx) {
          return Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: AnimatedBuilder(
                  animation: curve,
                  builder: (context, _) {
                    final double t = curve.value;
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: (0.9 + 0.1 * t).clamp(0.9, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: border, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, color: onBg, size: 22),
                                const SizedBox(width: 10),
                              ],
                              Flexible(
                                child: Text(
                                  message,
                                  style: context.textStyles.titleSmall?.medium.withColor(onBg),
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(entry);
      _activeCenterPopup = entry;
      controller.forward();

      Future.delayed(duration, () async {
        try {
          if (mounted) {
            await controller.reverse();
          }
        } catch (_) {}
        finally {
          if (entry.mounted) {
            try { entry.remove(); } catch (_) {}
          }
          _activeCenterPopup = null;
          try { controller.dispose(); } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Center popup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<GameService, AudioService, AchievementService, QuestService>(
      builder: (context, gameService, audioService, achievementService, questService, child) {
        // After the frame, check for newly spawned items to animate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ev = gameService.takeLastSpawnEvent();
          if (ev != null) {
            _playSpawnAnimation(ev.items, originX: ev.originX, originY: ev.originY);
          }
        });
        if (gameService.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading your game...', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.read<GameService>().forceLocalFallback(),
                    icon: Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.primary),
                    label: Text('Continue offline', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),
            ),
          );
        }

        final showTutorial = !gameService.playerStats.hasCompletedTutorial;

        return Scaffold(
          body: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppLevelTheme.gradientForLevel(context, gameService.currentLevel),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildTopBar(context, gameService),
                      Expanded(child: _buildGameGrid(context, gameService, audioService, achievementService, questService)),
                      _buildBottomBar(context, gameService),
                    ],
                  ),
                ),
              ),
              // Particle overlay across the whole screen
              Positioned.fill(child: ParticleField(key: _particleKey)),
              // Ghost overlay for merge animation
              if (_mergeController != null && _targetCenter != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _mergeController!,
                      builder: (context, _) {
                        final t = Curves.easeInOutCubic.transform(_mergeController!.value);
                        return CustomMultiChildLayout(
                          delegate: _GhostsLayoutDelegate(_ghosts, _targetCenter!, t),
                          children: [
                            for (int i = 0; i < _ghosts.length; i++)
                              LayoutId(id: i, child: _GhostEmoji(emoji: _ghosts[i].emoji, progress: t)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              // Ghost overlay for spawn animation (reverse)
              if (_spawnController != null && _spawnOrigin != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _spawnController!,
                      builder: (context, _) {
                        final t = Curves.easeOutBack.transform(_spawnController!.value);
                        return CustomMultiChildLayout(
                          delegate: _SpawnLayoutDelegate(_spawnGhosts, _spawnOrigin!, t),
                          children: [
                            for (int i = 0; i < _spawnGhosts.length; i++)
                              LayoutId(id: i, child: _SpawnEmoji(emoji: _spawnGhosts[i].emoji, progress: t)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              // Subtle screen pulse overlay
              if (_pulseController != null && _pulseCenter != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController!,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _PulsePainter(center: _pulseCenter!, progress: _pulseController!.value, color: Theme.of(context).colorScheme.primary),
                          size: Size.infinite,
                        );
                      },
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 30,
                  gravity: 0.2,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                ),
              ),
              if (showTutorial)
                TutorialOverlay(
                  onComplete: () {
                    gameService.completeTutorial();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, GameService gameService) {
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: EnergyBar(
                  current: gameService.playerStats.energy,
                  max: gameService.playerStats.maxEnergy,
                  onTap: () => context.push('/shop'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => context.push('/level'),
                child: Semantics(
                  button: true,
                  label: 'Open Level details',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Icon(Icons.auto_awesome, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Level ${gameService.currentLevel}', style: context.textStyles.labelLarge?.medium.withColor(Theme.of(context).colorScheme.onSurface)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CurrencyDisplay(
                icon: '💎',
                amount: gameService.playerStats.gems,
                onTap: () => context.push('/shop'),
              ),
              const SizedBox(width: AppSpacing.sm),
              CurrencyDisplay(
                icon: '🪙',
                amount: gameService.playerStats.coins,
              ),
              const Spacer(),
              IconButton.outlined(
                icon: const Icon(Icons.book),
                onPressed: () => context.push('/collection'),
                tooltip: 'Collection',
              ),
              IconButton.outlined(
                icon: const Icon(Icons.emoji_events),
                onPressed: () => context.push('/achievements'),
                tooltip: 'Achievements',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid(BuildContext context, GameService gameService, AudioService audioService, AchievementService achievementService, QuestService questService) {
    final gridSize = GameService.gridSize;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the full available space between the top and bottom bars
          const double padding = AppSpacing.sm;
          const double spacing = 4.0;
          final double availableW = constraints.maxWidth;
          final double availableH = constraints.maxHeight;
          final double innerW = availableW - padding * 2;
          final double innerH = availableH - padding * 2;
          final double cellW = (innerW - spacing * (gridSize - 1)) / gridSize;
          final double cellH = (innerH - spacing * (gridSize - 1)) / gridSize;
          final double childAspectRatio = (cellW <= 0 || cellH <= 0) ? 1.0 : (cellW / cellH);

          return SizedBox.expand(
            child: Container(
              key: _gridKey,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              padding: AppSpacing.paddingSm,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: gridSize * gridSize,
                itemBuilder: (context, index) {
                  final x = index % gridSize;
                  final y = index ~/ gridSize;
                  final item = gameService.gridItems.where((i) => i.gridX == x && i.gridY == y).firstOrNull;

                  if (item != null) {
                    final hidden = _animatingIds.contains(item.id);
                    return Opacity(
                      opacity: hidden ? 0.0 : 1.0,
                      child: GridItemWidget(
                        item: item,
                        isHighlighted: _highlightedItems.contains(item.id),
                        onTap: () => _onItemTap(item, gameService),
                        onLongPress: () => _onItemLongPress(item, gameService),
                      ),
                    );
                  }

                  final emptyCell = Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: _placingWildcard
                          ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 2)
                          : null,
                    ),
                  );
                  if (_placingWildcard) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () async {
                        context.read<AudioService>().maybeStartMusicFromUserGesture();
                        final ok = await gameService.abilityPlaceWildcardAt(x, y);
                        if (ok) {
                          if (mounted) {
                            setState(() => _placingWildcard = false);
                            context.read<HapticsService>().successSoft();
                            context.read<AudioService>().playAbilityUseSound();
                            _showMessage('Placed a Wildcard 🃏');
                          }
                        } else {
                          _showMessage('Can\'t place here');
                        }
                      },
                      child: emptyCell,
                    );
                  }
                  return emptyCell;
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, GameService gameService) {
    final canPowerMerge = _highlightedItems.length == 2 && _areTwoSameTier(gameService) && gameService.powerMergeCharges > 0;
    final canMergeNow = _highlightedItems.length >= 3 || canPowerMerge;
    final onBoardCount = gameService.gridItems.where((i) => i.gridX != null && i.gridY != null).length;
    final isBoardFull = onBoardCount >= GameService.gridSize * GameService.gridSize;
    final coins = gameService.playerStats.coins;
    final hasSelection = _selectedItem != null;
    final canAffordSummon = coins >= 80;
    final canAffordDuplicate = coins >= 120;
    final canAffordClear = coins >= 100;
    final canAffordShuffle = coins >= 150;
    final canAffordPowerMerge = coins >= 200;
    final canBomb = gameService.playerStats.bombRunes > 0 && hasSelection;
    final canWildcard = gameService.playerStats.wildcardOrbs > 0;
    final canTierUp = gameService.playerStats.tierUpTokens > 0 && hasSelection && !_selectedItem!.isWildcard && _selectedItem!.tier < GameService.totalTiers;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Abilities bar
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _AbilityButton(
                  icon: Icons.auto_awesome_motion,
                  label: 'Summon x4',
                  cost: 80,
                  color: Theme.of(context).colorScheme.tertiary,
                  onPressed: (isBoardFull || !canAffordSummon)
                      ? null
                      : () async {
                          context.read<AudioService>().playAbilityUseSound();
                          final ok = await gameService.abilitySummonBurst(count: 4, cost: 80);
                          if (ok) {
                            context.read<HapticsService>().onSummon();
                            _showMessage('Summoned new items ✨');
                          } else {
                            _showMessage(isBoardFull ? 'Board is full' : 'Not enough coins');
                          }
                        },
                ),
                _AbilityButton(
                  icon: Icons.content_copy,
                  label: 'Duplicate',
                  cost: 120,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: (hasSelection && canAffordDuplicate)
                      ? () async {
                          context.read<AudioService>().playAbilityUseSound();
                          final ok = await gameService.abilityDuplicateItem(_selectedItem!.id, cost: 120);
                          if (ok) { context.read<HapticsService>().onAbilityDuplicate(); _showMessage('Duplicated item ➕'); }
                          else _showMessage('Action failed or not enough coins');
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.cleaning_services,
                  label: 'Clear',
                  cost: 100,
                  color: Theme.of(context).colorScheme.error,
                  onPressed: (hasSelection && canAffordClear)
                      ? () async {
                          context.read<AudioService>().playAbilityUseSound();
                          final ok = await gameService.abilityClearItem(_selectedItem!.id, cost: 100);
                          if (ok) {
                            setState(() { _selectedItem = null; _highlightedItems.clear(); });
                            context.read<HapticsService>().onAbilityClear();
                            _showMessage('Cleared item 🧹');
                          } else {
                            _showMessage('Action failed or not enough coins');
                          }
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.shuffle,
                  label: 'Shuffle',
                  cost: 150,
                  color: Theme.of(context).colorScheme.secondary,
                  onPressed: canAffordShuffle
                      ? () async {
                          context.read<AudioService>().playAbilityUseSound();
                          final ok = await gameService.abilityShuffleBoard(cost: 150);
                          if (ok) { context.read<HapticsService>().onAbilityShuffle(); _showMessage('Shuffled the board 🔀'); }
                          else _showMessage('Not enough coins');
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.flash_on,
                  label: '2-Merge',
                  cost: 200,
                  trailing: gameService.powerMergeCharges > 0 ? 'x${gameService.powerMergeCharges}' : null,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  onPressed: canAffordPowerMerge
                      ? () async {
                          context.read<AudioService>().playAbilityUseSound();
                          final ok = await gameService.abilityBuyPowerMerge(charges: 1, cost: 200);
                          if (ok) { context.read<HapticsService>().onPowerMergePurchased(); _showMessage('Power Merge ready ⚡'); }
                          else _showMessage('Not enough coins');
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.auto_awesome,
                  label: 'Wildcard',
                  cost: 0,
                  trailing: gameService.playerStats.wildcardOrbs > 0 ? 'x${gameService.playerStats.wildcardOrbs}' : null,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: canWildcard
                      ? () async {
                          setState(() => _placingWildcard = !_placingWildcard);
                          if (_placingWildcard) {
                            _showCenterPopup('Tap an empty slot to place 🃏', icon: Icons.touch_app);
                          } else {
                            _showMessage('Wildcard placement cancelled');
                          }
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.local_fire_department,
                  label: 'Bomb',
                  cost: 0,
                  trailing: gameService.playerStats.bombRunes > 0 ? 'x${gameService.playerStats.bombRunes}' : null,
                  color: Theme.of(context).colorScheme.error,
                  onPressed: canBomb
                      ? () async {
                          final ok = await gameService.abilityBombArea(_selectedItem!.id);
                          if (ok) {
                            setState(() { _selectedItem = null; _highlightedItems.clear(); });
                            context.read<HapticsService>().onAbilityClear();
                            context.read<AudioService>().playBombSound();
                            _showMessage('Boom! Cleared area 💥');
                          } else {
                            _showMessage('No Bomb Rune or no target');
                          }
                        }
                      : null,
                ),
                _AbilityButton(
                  icon: Icons.upgrade,
                  label: 'Tier+',
                  cost: 0,
                  trailing: gameService.playerStats.tierUpTokens > 0 ? 'x${gameService.playerStats.tierUpTokens}' : null,
                  color: Theme.of(context).colorScheme.tertiary,
                  onPressed: canTierUp
                      ? () async {
                          final ok = await gameService.abilityTierUp(_selectedItem!.id);
                          if (ok) { context.read<HapticsService>().successSoft(); context.read<AudioService>().playAbilityUseSound(); _showMessage('Tier increased ⤴️'); }
                          else { _showMessage('Upgrade failed'); }
                        }
                      : null,
                ),
              ].map((w) => Padding(padding: const EdgeInsets.only(right: 12), child: w)).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canMergeNow
                      ? () => _performMerge(
                            gameService,
                            context.read<AudioService>(),
                            context.read<AchievementService>(),
                            context.read<QuestService>(),
                            context.read<HapticsService>(),
                          )
                      : null,
                  icon: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onPrimary, size: 26),
                  label: Text(
                    'Merge (${_highlightedItems.length})${canPowerMerge ? ' • Power' : ''}',
                    style: context.textStyles.titleMedium?.bold.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/daily-spin'),
                icon: Icon(Icons.casino, color: Theme.of(context).colorScheme.onSecondaryContainer, size: 26),
                label: Text('Spin', style: context.textStyles.titleMedium?.bold.copyWith(color: Theme.of(context).colorScheme.onSecondaryContainer)),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 18),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _areTwoSameTier(GameService gs) {
    if (_highlightedItems.length != 2) return false;
    final items = gs.gridItems.where((i) => _highlightedItems.contains(i.id)).toList();
    return items.length == 2 && items[0].tier == items[1].tier && items[0].tier < GameService.totalTiers;
  }
}

// ===================== Merge Animation Helpers =====================
class _Ghost {
  _Ghost({required this.emoji, required this.start});
  final String emoji;
  final Offset start; // global
}

class _GhostEmoji extends StatelessWidget {
  const _GhostEmoji({required this.emoji, required this.progress});
  final String emoji;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Scale down and fade out near the end
    final scale = 1.0 - (progress * 0.4);
    final opacity = 1.0 - (progress * 0.9);
    final glowColor = Theme.of(context).colorScheme.secondary;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale.clamp(0.6, 1.0),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 36,
            shadows: [
              Shadow(color: glowColor.withValues(alpha: 0.7), blurRadius: 12),
              Shadow(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5), blurRadius: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostsLayoutDelegate extends MultiChildLayoutDelegate {
  _GhostsLayoutDelegate(this.ghosts, this.target, this.t);
  final List<_Ghost> ghosts;
  final Offset target;
  final double t; // 0..1

  @override
  void performLayout(Size size) {
    for (int i = 0; i < ghosts.length; i++) {
      if (!hasChild(i)) continue;
      final boxSize = layoutChild(i, const BoxConstraints.tightFor(width: 28, height: 28));
      final g = ghosts[i];
      // Arc path: interpolate with slight perpendicular offset
      final start = g.start;
      final dir = (target - start);
      final len = dir.distance == 0 ? 1.0 : dir.distance;
      final norm = Offset(dir.dx / len, dir.dy / len);
      final perp = Offset(-norm.dy, norm.dx);
      final arc = perp * (1 - t) * 24.0; // 24px side arc shrinking over time
      final pos = Offset.lerp(start, target, t)! + arc;
      positionChild(i, Offset(pos.dx - boxSize.width / 2, pos.dy - boxSize.height / 2));
    }
  }

  @override
  bool shouldRelayout(covariant _GhostsLayoutDelegate oldDelegate) => oldDelegate.t != t || oldDelegate.ghosts != ghosts || oldDelegate.target != target;
}

extension on _GameBoardScreenState {
  Future<void> _playMergeAnimation(List<GameItem> items) async {
    try {
      if (_mergeController?.isAnimating == true) return;
      if (_gridKey.currentContext == null) return;
      final box = _gridKey.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) return;
      final gridTopLeft = box.localToGlobal(Offset.zero);
      final gridW = box.size.width;
      final gridH = box.size.height;
      const padding = AppSpacing.sm; // inner padding around grid content
      const spacing = 4.0; // GridView crossAxis/mainAxis spacing
      final innerW = gridW - padding * 2;
      final innerH = gridH - padding * 2;
      final cellW = (innerW - spacing * (GameService.gridSize - 1)) / GameService.gridSize;
      final cellH = (innerH - spacing * (GameService.gridSize - 1)) / GameService.gridSize;

      Offset cellCenter(int x, int y) => gridTopLeft + Offset(padding + x * (cellW + spacing) + cellW / 2, padding + y * (cellH + spacing) + cellH / 2);

      // Determine target cell (same as service integer average)
      final centerX = items.map((e) => e.gridX!).reduce((a, b) => a + b) ~/ items.length;
      final centerY = items.map((e) => e.gridY!).reduce((a, b) => a + b) ~/ items.length;
      final target = cellCenter(centerX, centerY);

      // Setup ghosts
      _ghosts = items.map((e) => _Ghost(emoji: e.emoji, start: cellCenter(e.gridX!, e.gridY!))).toList();
      _targetCenter = target;
      _animatingIds
        ..clear()
        ..addAll(items.map((e) => e.id));

      _mergeController?.dispose();
      _mergeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));

      _refresh();

      await _mergeController!.forward();
    } catch (e) {
      debugPrint('Merge animation failed: $e');
    } finally {
      // Clear ghost overlay and reveal items (actual removal happens after mergeItems)
      _mergeController?.dispose();
      _mergeController = null;
      _ghosts = [];
      _animatingIds.clear();
      _refresh();
    }
  }
}

// ===================== Spawn Animation Helpers (reverse of merge) =====================
class _SpawnGhost {
  _SpawnGhost({required this.emoji, required this.target});
  final String emoji;
  final Offset target; // global
}

class _SpawnEmoji extends StatelessWidget {
  const _SpawnEmoji({required this.emoji, required this.progress});
  final String emoji;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Slight scale up as it moves outward
    final scale = 0.9 + (progress * 0.2);
    final opacity = (progress * 1.0).clamp(0.0, 1.0);
    final glowColor = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale.clamp(0.9, 1.1),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 32,
            shadows: [
              Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 10),
              Shadow(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4), blurRadius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpawnLayoutDelegate extends MultiChildLayoutDelegate {
  _SpawnLayoutDelegate(this.ghosts, this.origin, this.t);
  final List<_SpawnGhost> ghosts;
  final Offset origin;
  final double t; // 0..1

  @override
  void performLayout(Size size) {
    for (int i = 0; i < ghosts.length; i++) {
      if (!hasChild(i)) continue;
      final boxSize = layoutChild(i, const BoxConstraints.tightFor(width: 28, height: 28));
      final g = ghosts[i];
      // Slight arc outwards similar to merge but reversed
      final dir = (g.target - origin);
      final len = dir.distance == 0 ? 1.0 : dir.distance;
      final norm = Offset(dir.dx / len, dir.dy / len);
      final perp = Offset(-norm.dy, norm.dx);
      final arc = perp * (1 - t) * 18.0; // diminishing side arc
      final pos = Offset.lerp(origin, g.target, t)! + arc;
      positionChild(i, Offset(pos.dx - boxSize.width / 2, pos.dy - boxSize.height / 2));
    }
  }

  @override
  bool shouldRelayout(covariant _SpawnLayoutDelegate oldDelegate) => oldDelegate.t != t || oldDelegate.ghosts != ghosts || oldDelegate.origin != origin;
}

extension on _GameBoardScreenState {
  Future<void> _playSpawnAnimation(List<GameItem> items, {required int originX, required int originY}) async {
    try {
      if (_spawnController?.isAnimating == true) return;
      if (_gridKey.currentContext == null) return;
      final box = _gridKey.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) return;
      final gridTopLeft = box.localToGlobal(Offset.zero);
      final gridW = box.size.width;
      final gridH = box.size.height;
      const padding = AppSpacing.sm;
      const spacing = 4.0;
      final innerW = gridW - padding * 2;
      final innerH = gridH - padding * 2;
      final cellW = (innerW - spacing * (GameService.gridSize - 1)) / GameService.gridSize;
      final cellH = (innerH - spacing * (GameService.gridSize - 1)) / GameService.gridSize;

      Offset cellCenter(int x, int y) => gridTopLeft + Offset(padding + x * (cellW + spacing) + cellW / 2, padding + y * (cellH + spacing) + cellH / 2);

      // Setup ghosts
      final origin = cellCenter(originX, originY);
      _spawnOrigin = origin;
      _spawnGhosts = items
          .where((e) => e.gridX != null && e.gridY != null)
          .map((e) => _SpawnGhost(emoji: e.emoji, target: cellCenter(e.gridX!, e.gridY!)))
          .toList();

      // Hide real items during animation to avoid double rendering
      _animatingIds
        ..clear()
        ..addAll(items.map((e) => e.id));

      _spawnController?.dispose();
      _spawnController = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

      _refresh();

      await _spawnController!.forward();
    } catch (e) {
      debugPrint('Spawn animation failed: $e');
    } finally {
      _spawnController?.dispose();
      _spawnController = null;
      _spawnGhosts = [];
      _spawnOrigin = null;
      _animatingIds.clear();
      _refresh();
    }
  }

  void _triggerScreenPulse({required Offset center, required int tier, required bool reducedMotion}) {
    try {
      _pulseController?.dispose();
      final duration = reducedMotion ? const Duration(milliseconds: 220) : const Duration(milliseconds: 360);
      _pulseController = AnimationController(vsync: this, duration: duration)..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _pulseController?.dispose();
            _pulseController = null;
            _pulseCenter = null;
            _refresh();
          }
        });
      _pulseCenter = center;
      _refresh();
      _pulseController?.forward();
    } catch (e) {
      debugPrint('Pulse start failed: $e');
    }
  }

  void _showComboBanner({required int tier, required int selectionCount}) {
    try {
      // Remove any existing popup to avoid stacking banners
      final overlay = Overlay.of(context);
      final cs = Theme.of(context).colorScheme;
      final Color bg = cs.primaryContainer.withValues(alpha: 0.95);
      final Color onBg = cs.onPrimaryContainer;
      final entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), reverseDuration: const Duration(milliseconds: 160));
      final curve = CurvedAnimation(parent: entryController, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      final entry = OverlayEntry(builder: (ctx) {
        return Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: true,
            child: AnimatedBuilder(
              animation: curve,
              builder: (_, __) {
                final t = curve.value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (-20 * (1 - t)).clamp(0, 20)),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome, color: onBg, size: 18),
                          const SizedBox(width: 8),
                          Text('Tier $tier merge • $selectionCount', style: context.textStyles.titleSmall?.bold.withColor(onBg)),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });
      overlay.insert(entry);
      entryController.forward();
      Future.delayed(const Duration(milliseconds: 1100), () async {
        try { await entryController.reverse(); } catch (_) {}
        finally { entry.remove(); entryController.dispose(); }
      });
    } catch (e) {
      debugPrint('Combo banner failed: $e');
    }
  }
}

// ===================== UI: Ability Button =====================
class _AbilityButton extends StatelessWidget {
  const _AbilityButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.color,
    this.trailing,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final int cost;
  final Color color;
  final String? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    final cs = Theme.of(context).colorScheme;
    final activeFg = _bestOnColor(context, color);
    final disabledBg = cs.surfaceContainerHighest;
    final disabledFg = cs.onSurfaceVariant;
    final fg = isDisabled ? disabledFg : activeFg;
    return Semantics(
      label: 'Ability: $label${cost > 0 ? ', cost $cost coins' : ''}',
      hint: isDisabled ? 'Unavailable' : 'Double tap to activate ability',
      button: true,
      enabled: !isDisabled,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: activeFg,
          disabledBackgroundColor: disabledBg,
          disabledForegroundColor: disabledFg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 6),
            Text(label, style: context.textStyles.labelMedium?.bold.withColor(fg)),
            if (cost > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(children: [
                  const Text('🪙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text('$cost', style: context.textStyles.labelSmall?.bold.withColor(fg)),
                ]),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(trailing!, style: context.textStyles.labelSmall?.bold.withColor(fg)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _bestOnColor(BuildContext context, Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.center, required this.progress, required this.color});
  final Offset center;
  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Expand radius to cover screen diagonally
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final radius = (maxRadius * progress).clamp(0.0, maxRadius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.18 * (1 - progress)), color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.center != center || oldDelegate.color != color;
}
