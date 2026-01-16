import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/storage_service.dart';
import 'package:mergeworks/models/spin_reward.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/haptics_service.dart';
import 'package:mergeworks/widgets/ads_banner.dart';
import 'package:mergeworks/services/popup_manager.dart';

class DailySpinScreen extends StatefulWidget {
  const DailySpinScreen({super.key});

  @override
  State<DailySpinScreen> createState() => _DailySpinScreenState();
}

class _DailySpinScreenState extends State<DailySpinScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late AnimationController _controller;
  bool _isSpinning = false;
  bool _canSpin = true;
  static const int _extraSpinGemCost = 30;

  final List<SpinReward> _rewards = [
    SpinReward(id: '1', name: '10 Gems', icon: '💎', type: RewardType.gems, amount: 10, probability: 0.3),
    SpinReward(id: '2', name: '50 Coins', icon: '🪙', type: RewardType.coins, amount: 50, probability: 0.3),
    SpinReward(id: '3', name: '20 Energy', icon: '⚡', type: RewardType.energy, amount: 20, probability: 0.2),
    SpinReward(id: '4', name: '100 Coins', icon: '🪙', type: RewardType.coins, amount: 100, probability: 0.1),
    SpinReward(id: '5', name: '50 Gems', icon: '💎', type: RewardType.gems, amount: 50, probability: 0.07),
    SpinReward(id: '6', name: '100 Energy', icon: '⚡', type: RewardType.energy, amount: 100, probability: 0.03),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _checkSpinAvailability();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSpinAvailability() async {
    final lastSpin = await _storage.loadLastSpinDate();
    if (lastSpin != null) {
      final now = DateTime.now();
      final diff = now.difference(lastSpin);
      if (diff.inHours < 24) {
        setState(() => _canSpin = false);
      }
    }
  }

  Future<void> _spin({bool paid = false}) async {
    if ((!paid && !_canSpin) || _isSpinning) return;

    setState(() => _isSpinning = true);

    final reward = _selectReward();

    _controller.reset();
    await _controller.forward();

    if (!paid) {
      await _storage.saveLastSpinDate(DateTime.now());
    }

    if (mounted) {
      final gameService = context.read<GameService>();
      switch (reward.type) {
        case RewardType.gems:
          await gameService.addGems(reward.amount);
          break;
        case RewardType.coins:
          await gameService.addCoins(reward.amount);
          break;
        case RewardType.energy:
          await gameService.addEnergy(reward.amount);
          break;
      }

      // Haptics: emphasize big wins
      context.read<HapticsService>().onSpinWin(type: reward.type, amount: reward.amount);

      setState(() {
        _isSpinning = false;
        if (!paid) _canSpin = false;
      });

      _showRewardDialog(reward);
    }
  }

  Future<void> _buyExtraSpin() async {
    if (_isSpinning) return;
    final game = context.read<GameService>();
    final ok = await game.purchaseExtraDailySpin(gemCost: _extraSpinGemCost);
    if (!ok) {
      // Not enough gems -> suggest visiting Shop
      if (!mounted) return;
      unawaited(
        context.read<PopupManager>().showAppDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Not enough gems'),
                content: const Text('Earn more from merges, Daily Spin, or buy Specials in the Shop.'),
                actions: [
                  TextButton(onPressed: () => context.pop(), child: const Text('OK')),
                  FilledButton(
                    onPressed: () {
                      context.pop();
                      context.push('/shop');
                    },
                    child: const Text('Open Shop'),
                  ),
                ],
              ),
            ),
      );
      return;
    }
    // Haptics cue for purchase, then spin immediately
    await context.read<HapticsService>().successSoft();
    if (!mounted) return;
    await _spin(paid: true);
  }

  SpinReward _selectReward() {
    final random = Random().nextDouble();
    double cumulative = 0.0;
    
    for (final reward in _rewards) {
      cumulative += reward.probability;
      if (random <= cumulative) {
        return reward;
      }
    }
    
    return _rewards.first;
  }

  void _showRewardDialog(SpinReward reward) {
    unawaited(
      context.read<PopupManager>().showAppDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('🎉 Congratulations!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reward.icon, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'You won ${reward.name}!',
                    style: context.textStyles.titleLarge?.bold.copyWith(color: Theme.of(context).colorScheme.primary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    context.pop();
                    context.pop();
                  },
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Spin Wheel'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: const AdsBanner(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wheelSize = min(340.0, max(240.0, constraints.maxWidth - 48));

            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _canSpin ? 'Spin for Free Rewards!' : 'Come back tomorrow!',
                              style: context.textStyles.headlineMedium?.bold.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _controller.value * 2 * pi * 3,
                                  child: Container(
                                    width: wheelSize,
                                    height: wheelSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.secondary,
                                          Theme.of(context).colorScheme.tertiary,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: List.generate(
                                        _rewards.length,
                                        (index) {
                                          final angle = (2 * pi / _rewards.length) * index;
                                          final radius = wheelSize * 0.34;
                                          final center = wheelSize / 2;
                                          final x = radius * cos(angle);
                                          final y = radius * sin(angle);

                                          return Positioned(
                                            left: center + x - 28,
                                            top: center + y - 28,
                                            child: Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _rewards[index].icon,
                                                  style: const TextStyle(fontSize: 28),
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
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            if (_canSpin)
                              FilledButton.icon(
                                onPressed: _isSpinning ? null : () => _spin(),
                                icon: _isSpinning
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(Icons.casino, color: Theme.of(context).colorScheme.onPrimary, size: 28),
                                label: Text(
                                  _isSpinning ? 'Spinning...' : 'Spin Now!',
                                  style: context.textStyles.titleMedium?.bold.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 18),
                                  shape: const StadiumBorder(),
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Container(
                                    padding: AppSpacing.paddingMd,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(AppRadius.lg),
                                    ),
                                    child: Text(
                                      '⏰ Next free spin in ${24 - DateTime.now().hour}h',
                                      style: context.textStyles.titleSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Consumer<GameService>(
                                    builder: (context, game, _) {
                                      final canAfford = game.playerStats.gems >= _extraSpinGemCost;
                                      return FilledButton.icon(
                                        onPressed: _isSpinning || !canAfford ? null : _buyExtraSpin,
                                        icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                                        label: Text(
                                          'Buy Extra Spin • 💎 $_extraSpinGemCost',
                                          style: context.textStyles.titleSmall?.bold.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              canAfford ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.surfaceContainerHigh,
                                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                                          shape: const StadiumBorder(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Possible Rewards:',
                              style: context.textStyles.titleSmall?.bold.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              alignment: WrapAlignment.center,
                              children: _rewards.map((reward) {
                                return Chip(
                                  avatar: Text(reward.icon),
                                  label: Text(reward.name),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
