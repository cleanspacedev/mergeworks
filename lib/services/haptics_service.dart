import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mergeworks/models/spin_reward.dart';

/// Centralized haptics with simple, distinctive patterns per action.
/// Uses Flutter's built-in HapticFeedback APIs (no extra plugins) and guards
/// against unsupported platforms.
class HapticsService {
  bool enabled = true; // future: expose via Settings

  Future<void> _try(Future<void> Function() fn) async {
    if (!enabled) return;
    try {
      await fn();
    } catch (e) {
      debugPrint('Haptics error: $e');
    }
  }

  // Basic building blocks
  Future<void> light() => _try(HapticFeedback.lightImpact);
  Future<void> medium() => _try(HapticFeedback.mediumImpact);
  Future<void> heavy() => _try(HapticFeedback.heavyImpact);
  Future<void> select() => _try(HapticFeedback.selectionClick);
  Future<void> tick() => _try(HapticFeedback.vibrate);

  // Composite patterns
  Future<void> successSoft() async {
    await medium();
    await Future.delayed(const Duration(milliseconds: 35));
    await light();
  }

  Future<void> successStrong() async {
    await heavy();
    await Future.delayed(const Duration(milliseconds: 55));
    await medium();
    await Future.delayed(const Duration(milliseconds: 40));
    await light();
  }

  Future<void> rippleQuick3() async {
    await light();
    await Future.delayed(const Duration(milliseconds: 40));
    await light();
    await Future.delayed(const Duration(milliseconds: 40));
    await light();
  }

  // Domain-specific cues
  Future<void> onMerge({required int selectionCount, required int resultingTier}) async {
    // Heavier feedback for larger merges or higher tiers
    if (selectionCount >= 4 || resultingTier >= 10) {
      await successStrong();
    } else if (selectionCount == 2) {
      // Power merge: a punchy medium + light
      await successSoft();
    } else {
      // Regular 3-merge
      await medium();
    }
  }

  Future<void> onAbilityShuffle() => rippleQuick3();
  Future<void> onAbilityDuplicate() => successSoft();
  Future<void> onAbilityClear() async {
    await select();
    await Future.delayed(const Duration(milliseconds: 30));
    await light();
  }
  Future<void> onPowerMergePurchased() => successSoft();
  Future<void> onSummon() => light();

  Future<void> onSpinWin({required RewardType type, required int amount}) async {
    switch (type) {
      case RewardType.gems:
        if (amount >= 50) {
          await successStrong();
        } else {
          await successSoft();
        }
        break;
      case RewardType.coins:
        if (amount >= 100) {
          await successStrong();
        } else {
          await medium();
        }
        break;
      case RewardType.energy:
        if (amount >= 100) {
          await successStrong();
        } else {
          await light();
        }
        break;
    }
  }
}
