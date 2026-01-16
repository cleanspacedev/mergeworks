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
import 'package:mergeworks/widgets/hint_offer_sheet.dart';
import 'package:mergeworks/widgets/no_moves_offer_sheet.dart';
import 'package:mergeworks/widgets/no_energy_offer_sheet.dart';
import 'package:mergeworks/widgets/no_summons_offer_sheet.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/services/accessibility_service.dart';
import 'package:mergeworks/services/haptics_service.dart';
import 'package:mergeworks/services/connectivity_service.dart';
import 'package:mergeworks/services/shop_service.dart';
import 'package:mergeworks/services/popup_manager.dart';
import 'package:mergeworks/nav.dart';

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
  bool _placingWildcard = false; // When true, tapping an empty cell places a wildcard

  // Hint / idle handling
  static const int _hintGemCost = 10;
  static const Duration _idleHintDelay = Duration(seconds: 30);
  Timer? _idleTimer;
  bool _isHintSheetOpen = false;
  bool _isNoMovesSheetOpen = false;
  bool _isNoEnergySheetOpen = false;
  bool _noEnergyOfferShownForEpisode = false;
  Timer? _noEnergyOfferTimer;
  final Set<String> _hintedItems = {};
  Timer? _hintClearTimer;

  String? _lastNoMovesSignature;
  String? _pendingNoMovesSignature;
  Timer? _noMovesOfferTimer;

  // Delay before showing the “no moves” offer once the board becomes stuck.
  // This prevents instant popups on refresh and gives the player time to notice.
  static const Duration _noMovesOfferDelay = Duration(seconds: 30);

  static const Duration _noEnergyOfferDelay = Duration(seconds: 6);

  /// Returns the same set of items that are effectively *visible* on the grid,
  /// matching the GridView's `firstOrNull` selection behavior.
  ///
  /// This protects hint/highlight logic from accidentally targeting “duplicate”
  /// items that share a cell but are not actually rendered.
  List<GameItem> _visibleBoardItems(GameService gs, {Set<String> excludedIds = const {}}) {
    final byCell = <String, GameItem>{};
    for (final gi in gs.gridItems) {
      final x = gi.gridX;
      final y = gi.gridY;
      if (x == null || y == null) continue;
      if (excludedIds.contains(gi.id)) continue;
      final key = '$x,$y';
      byCell.putIfAbsent(key, () => gi);
    }
    return byCell.values.toList();
  }

  // Prevent false-positive “no moves” offers immediately after a refresh while
  // the board is still loading/syncing.
  bool _didInitialMoveCheck = false;

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
    _resetIdleTimer();
  }

  Future<void> _runInitialMoveCheckIfNeeded(GameService gs) async {
    if (!mounted || _didInitialMoveCheck) return;
    if (gs.isLoading) return;
    if (!_isOnGameBoardRoute()) return;
    if (!gs.playerStats.hasCompletedTutorial) {
      _didInitialMoveCheck = true;
      return;
    }

    // Defer one frame to let any just-finished async loads/syncs settle.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didInitialMoveCheck) return;
      final gameService = context.read<GameService>();
      if (gameService.isLoading) return;

      try {
        final availability = gameService.evaluateMoveAvailability();
        final sig = _computeNoMovesSignature(gameService);

        if (availability.boardHasAnyMoves && !availability.hasSufficientEnergy) {
          // If the player is blocked primarily by energy, offer energy rather than “no moves”.
          unawaited(_maybeShowNoEnergyOffer(gameService, reason: 'initial_load_check'));
          return;
        }

        // If there ARE moves, synchronize the debounce signature immediately so
        // we never open the sheet due to a stale/empty pre-load state.
        if (availability.hasSufficientEnergy && availability.boardHasStandardMoves) {
          // Defensive: On rare load/sync frames, move detection may say there is
          // a standard move, but our hint selection cannot materialize a valid
          // 3+ merge. Treat that as “stuck” for UX so we don't offer broken hints.
          if (_hasValidStandardHintCandidate(gameService)) {
            _lastNoMovesSignature = sig;
          } else {
            unawaited(_maybeShowNoMovesOffer(gameService, reason: 'initial_load_hint_mismatch'));
          }
        } else if (availability.hasSufficientEnergy && !availability.boardHasStandardMoves) {
          // If the board is truly stuck after load, it's OK to offer.
          unawaited(_maybeShowNoMovesOffer(gameService, reason: 'initial_load_check'));
        }
      } catch (e) {
        debugPrint('Initial move check failed: $e');
      } finally {
        _didInitialMoveCheck = true;
      }
    });
  }

  bool _isOnGameBoardRoute() {
    try {
      final uri = GoRouter.of(context).routeInformationProvider.value.uri;
      return uri.path == AppRoutes.home;
    } catch (e) {
      // If go_router isn't available in this context for any reason, fail safe.
      debugPrint('Failed to read current route for hint/no-moves gating: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _hintClearTimer?.cancel();
    _noMovesOfferTimer?.cancel();
    _noEnergyOfferTimer?.cancel();
    _mergeController?.dispose();
    _spawnController?.dispose();
    _pulseController?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _cancelNoMovesOfferTimer() {
    _noMovesOfferTimer?.cancel();
    _noMovesOfferTimer = null;
    _pendingNoMovesSignature = null;
  }

  void _cancelNoEnergyOfferTimer() {
    _noEnergyOfferTimer?.cancel();
    _noEnergyOfferTimer = null;
  }

  void _registerUserInteraction() {
    // Any interaction counts (tap, drag, etc.).
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleHintDelay, _handleIdleTimeout);
  }

  Future<bool?> _showHintOfferSheet() async {
    if (!mounted || !_isOnGameBoardRoute()) return null;

    // Guard: never open the hint offer UI if the board has no valid standard
    // (3-item) merges. This can happen if the board changed between scheduling
    // the idle prompt and actually opening the sheet, or if the hint sheet is
    // triggered from another UI entry point.
    try {
      final gameService = context.read<GameService>();
      final availability = gameService.evaluateMoveAvailability();
      if (!availability.boardHasStandardMoves || !_hasValidStandardHintCandidate(gameService)) {
        _showCenterPopup('No matches left', icon: Icons.search_off);
        unawaited(_maybeShowNoMovesOffer(gameService, reason: 'hint_sheet_no_moves'));
        return null;
      }
    } catch (e) {
      debugPrint('Failed to validate hint sheet preconditions: $e');
      // If we cannot validate, fall through and try to show the sheet; the
      // reveal step still defensively checks before charging gems.
    }

    _isHintSheetOpen = true;
    try {
      final gameService = context.read<GameService>();
      final gems = gameService.playerStats.gems;
      final canAfford = gems >= _hintGemCost;
      return await context.read<PopupManager>().showBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => HintOfferSheet(costGems: _hintGemCost, canAfford: canAfford, currentGems: gems),
          );
    } catch (e) {
      debugPrint('Failed to show hint offer sheet: $e');
      return null;
    } finally {
      _isHintSheetOpen = false;
    }
  }

  Future<void> _revealHint({required int cost}) async {
    final gameService = context.read<GameService>();
    final audio = context.read<AudioService>();
    final haptics = context.read<HapticsService>();

    if (gameService.playerStats.gems < cost) {
      _showMessage('Not enough gems 💎');
      return;
    }

    // Compute the hint BEFORE charging, so the player never pays if the board is
    // actually stuck (or if the state changed between the offer sheet and now).
    // Also exclude any items currently hidden by animations (merge/spawn),
    // otherwise the user can briefly *see* only 2 highlighted tiles.
    final hintIds = _findMergeHintIds(gameService, excludedIds: _animatingIds);
    final currentItems = _visibleBoardItems(gameService, excludedIds: _animatingIds).where((gi) => hintIds.contains(gi.id)).toList();
    // Defensive: never show a 2-item “hint”. Hints are for standard 3+ merges.
    if (hintIds.length < 3 || currentItems.length < 3 || !gameService.canMerge(currentItems)) {
      _showCenterPopup('No merges found… try summoning!', icon: Icons.search_off);
      unawaited(_maybeShowNoMovesOffer(gameService, reason: 'reveal_no_standard_merge'));
      return;
    }

    // Spend gems.
    await gameService.addGems(-cost);
    audio.playAbilityUseSound();
    haptics.successSoft();

    _hintClearTimer?.cancel();
    setState(() {
      _hintedItems
        ..clear()
        ..addAll(hintIds);
    });

    _showCenterPopup('Hint revealed ✨', icon: Icons.lightbulb);
    _hintClearTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _hintedItems.clear());
    });
  }

  Set<String> _findMergeHintIds(GameService gameService, {Set<String> excludedIds = const {}}) {
    try {
      // Hints are meant to teach/guide the *standard* merge rule (3+ connected).
      // Even if the player has Power Merge charges, we avoid showing “2-item”
      // hints because it feels like a false positive when the board is stuck
      // for normal merges.
      const minNeeded = 3;
      final onBoard = _visibleBoardItems(gameService, excludedIds: excludedIds);
      if (onBoard.isEmpty) return {};

      bool isEligible(GameItem gi, int baseTier) => gi.isWildcard || gi.tier == baseTier;

      // Prefer the lowest tier merges first to keep hints “obvious”.
      onBoard.sort((a, b) {
        final ta = a.isWildcard ? 9999 : a.tier;
        final tb = b.isWildcard ? 9999 : b.tier;
        final byTier = ta.compareTo(tb);
        if (byTier != 0) return byTier;
        final ax = a.gridX ?? 0, ay = a.gridY ?? 0;
        final bx = b.gridX ?? 0, by = b.gridY ?? 0;
        final da = (ax - 2).abs() + (ay - 2).abs();
        final db = (bx - 2).abs() + (by - 2).abs();
        return da.compareTo(db);
      });

      for (final anchor in onBoard) {
        if (anchor.isWildcard) continue; // avoid ambiguous “all-wildcard” anchor
        final baseTier = anchor.tier;
        final visited = <String>{};
        final queue = <GameItem>[anchor];
        final picked = <GameItem>[];

        visited.add(anchor.id);

        while (queue.isNotEmpty) {
          final cur = queue.removeAt(0);
          picked.add(cur);
          for (final other in onBoard) {
            if (visited.contains(other.id)) continue;
            if (!isEligible(other, baseTier)) continue;
            if (_areAdjacent8(cur, other)) {
              visited.add(other.id);
              queue.add(other);
            }
          }
        }

        if (picked.length < minNeeded) continue;

        // Take the closest minNeeded items to the anchor so the hint is small and clear.
        int distSq(GameItem a) {
          final dx = (a.gridX! - anchor.gridX!);
          final dy = (a.gridY! - anchor.gridY!);
          return dx * dx + dy * dy;
        }

        picked.sort((a, b) => distSq(a).compareTo(distSq(b)));
        final hint = picked.take(minNeeded).map((e) => e.id).toSet();

        // Validate with the game rule engine (includes energy check).
        final itemsToMerge = _visibleBoardItems(gameService, excludedIds: excludedIds).where((gi) => hint.contains(gi.id)).toList();
        if (gameService.canMerge(itemsToMerge)) return hint;
      }
    } catch (e) {
      debugPrint('Failed to compute hint: $e');
    }
    return {};
  }

  Future<void> _handleIdleTimeout() async {
    if (!mounted || _isHintSheetOpen) return;

    // Critical: the GameBoard screen can remain mounted underneath other routes
    // (e.g. LevelScreen). Never show hint/no-moves UI unless the user is
    // currently viewing the home/game route.
    if (!_isOnGameBoardRoute()) {
      if (mounted) _resetIdleTimer();
      return;
    }

    final gameService = context.read<GameService>();
    final showTutorial = !gameService.playerStats.hasCompletedTutorial;
    if (showTutorial) {
      _resetIdleTimer();
      return;
    }

    final availability = gameService.evaluateMoveAvailability();
    // If the board has moves but the player can't afford even the cheapest one,
    // offer an energy refill instead.
    if (availability.boardHasAnyMoves && !availability.hasSufficientEnergy) {
      await _maybeShowNoEnergyOffer(gameService, reason: 'idle');
      if (mounted) _resetIdleTimer();
      return;
    }

    // If the board has no legal standard merges, don't show the hint offer.
    if (!availability.boardHasStandardMoves) {
      await _maybeShowNoMovesOffer(gameService, reason: 'idle');
      if (mounted) _resetIdleTimer();
      return;
    }

    // Extra guard: only offer hints if we can actually compute a standard (3+) merge.
    // This avoids rare edge cases where the move-detection and hint selection could
    // temporarily disagree due to async updates.
    final hintCandidate = _findMergeHintIds(gameService, excludedIds: _animatingIds);
    final hintItems = gameService.gridItems.where((gi) => hintCandidate.contains(gi.id) && !_animatingIds.contains(gi.id)).toList();
    if (hintCandidate.length < 3 || hintItems.length < 3 || !gameService.canMerge(hintItems)) {
      await _maybeShowNoMovesOffer(gameService, reason: 'idle_hint_mismatch');
      if (mounted) _resetIdleTimer();
      return;
    }

    if (gameService.playerStats.gems < _hintGemCost) {
      _resetIdleTimer();
      return;
    }

    final shouldReveal = await _showHintOfferSheet();
    // Treat closing the sheet as “interaction” so it won’t re-open instantly.
    if (mounted) _resetIdleTimer();
    if (shouldReveal == true && mounted) {
      await _revealHint(cost: _hintGemCost);
    }
  }

  String _computeNoMovesSignature(GameService gs) {
    final buffer = StringBuffer();
    // Signature for debouncing the “no standard moves” offer.
    // IMPORTANT: Do NOT include energy in this signature.
    // Energy can regenerate while the board is stuck, which would constantly
    // change the signature and prevent the delayed no-moves offer from ever
    // firing.
    //
    // Power Merge charges are also intentionally excluded because they don't
    // affect whether *standard* 3-item merges exist, and including them can
    // cause the sheet to reopen unexpectedly after buying/consuming charges.
    for (final i in gs.gridItems) {
      buffer.write('${i.id}:${i.tier}:${i.gridX}:${i.gridY}:${i.isWildcard ? 1 : 0};');
    }
    return buffer.toString();
  }

  bool _hasValidStandardHintCandidate(GameService gs) {
    try {
      final candidate = _findMergeHintIds(gs, excludedIds: _animatingIds);
      if (candidate.length < 3) return false;
      final items = _visibleBoardItems(gs, excludedIds: _animatingIds).where((gi) => candidate.contains(gi.id)).toList();
      if (items.length < 3) return false;
      return gs.canMerge(items);
    } catch (e) {
      debugPrint('Failed to validate hint candidate: $e');
      return false;
    }
  }

  bool _canSummonNow(GameService gs) {
    final occupied = gs.gridItems.where((i) => i.gridX != null && i.gridY != null).map((i) => '${i.gridX}_${i.gridY}').toSet();
    for (int y = 0; y < GameService.gridSize; y++) {
      for (int x = 0; x < GameService.gridSize; x++) {
        if (!occupied.contains('${x}_$y')) return true;
      }
    }
    return false;
  }

  Future<NoMovesOfferAction?> _showNoMovesOfferSheet({required int summonCount, required int discountedCost, required int originalCost}) async {
    if (!mounted || !_isOnGameBoardRoute()) return null;
    _isNoMovesSheetOpen = true;
    try {
      final gs = context.read<GameService>();
      final gems = gs.playerStats.gems;
      final canSummon = _canSummonNow(gs);
      final canAfford = gems >= discountedCost;
      final shop = context.read<ShopService>();
      final cheapestGemPack = shop.cheapestGemPack();
      final cheapestGemPriceLabel = cheapestGemPack == null ? null : (shop.priceLabelFor(cheapestGemPack.id) ?? '\$${cheapestGemPack.price.toStringAsFixed(2)}');
       return await context.read<PopupManager>().showBottomSheet<NoMovesOfferAction>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => NoMovesOfferSheet(
              summonCount: summonCount,
              discountedCost: discountedCost,
              originalCost: originalCost,
              currentGems: gems,
              canSummon: canSummon,
              canAfford: canAfford,
              cheapestGemPackLabel: cheapestGemPack?.name,
              cheapestGemPackPriceLabel: cheapestGemPriceLabel,
            ),
          );
    } catch (e) {
      debugPrint('Failed to show no-moves offer sheet: $e');
      return null;
    } finally {
      _isNoMovesSheetOpen = false;
    }
  }

  Future<bool?> _showNoSummonsOfferSheet({required int discountedCost, required int originalCost}) async {
    if (!mounted || !_isOnGameBoardRoute()) return null;
    _isNoMovesSheetOpen = true;
    try {
      final gs = context.read<GameService>();
      final coins = gs.playerStats.coins;
      final canAfford = coins >= discountedCost;
      return await context.read<PopupManager>().showBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => NoSummonsOfferSheet(
              discountedCost: discountedCost,
              originalCost: originalCost,
              currentCoins: coins,
              canAfford: canAfford,
            ),
          );
    } catch (e) {
      debugPrint('Failed to show no-summons offer sheet: $e');
      return null;
    } finally {
      _isNoMovesSheetOpen = false;
    }
  }

  Future<void> _maybeShowNoMovesOffer(GameService gs, {required String reason}) async {
    if (!mounted || _isNoMovesSheetOpen) return;
    if (!_isOnGameBoardRoute()) return;
    if (!gs.playerStats.hasCompletedTutorial) return;

    final availability = gs.evaluateMoveAvailability();
    // Being blocked by energy is not “no moves”. Show the energy offer instead.
    if (availability.boardHasAnyMoves && !availability.hasSufficientEnergy) {
      _cancelNoMovesOfferTimer();
      unawaited(_maybeShowNoEnergyOffer(gs, reason: 'no_moves_redirect_$reason'));
      return;
    }

    // Don't show if there are moves.
    if (availability.boardHasStandardMoves) {
      _cancelNoMovesOfferTimer();
      return;
    }

    // Debounce per-board-state to avoid re-opening repeatedly, but with a delay.
    // We only “commit” (_lastNoMovesSignature) once we actually show the sheet.
    final sig = _computeNoMovesSignature(gs);
    if (_lastNoMovesSignature == sig) return;
    if (_pendingNoMovesSignature == sig && _noMovesOfferTimer?.isActive == true) return;

    _pendingNoMovesSignature = sig;
    _noMovesOfferTimer?.cancel();
    _noMovesOfferTimer = Timer(_noMovesOfferDelay, () async {
      if (!mounted || _isNoMovesSheetOpen) return;
      if (!_isOnGameBoardRoute()) return;

      final gameService = context.read<GameService>();
      if (gameService.isLoading) return;

      try {
        final availabilityNow = gameService.evaluateMoveAvailability();
        if ((availabilityNow.boardHasAnyMoves && !availabilityNow.hasSufficientEnergy) || availabilityNow.boardHasStandardMoves) {
          _cancelNoMovesOfferTimer();
          return;
        }

        final sigNow = _computeNoMovesSignature(gameService);
        if (_pendingNoMovesSignature != sigNow) return; // board changed during delay
        if (_lastNoMovesSignature == sigNow) {
          _cancelNoMovesOfferTimer();
          return;
        }

        _lastNoMovesSignature = sigNow;
        _pendingNoMovesSignature = null;
        _noMovesOfferTimer = null;

        // If the board is full, summoning can't help. Offer a discounted shuffle instead.
        if (!_canSummonNow(gameService)) {
          const shuffleOriginalCost = 150;
          const shuffleDiscountedCost = 75;
          final shouldShuffle = await _showNoSummonsOfferSheet(discountedCost: shuffleDiscountedCost, originalCost: shuffleOriginalCost);
          if (!mounted) return;
          if (shouldShuffle == true) {
            final audio = context.read<AudioService>();
            final haptics = context.read<HapticsService>();
            audio.playAbilityUseSound();
            final ok = await gameService.abilityShuffleBoard(cost: shuffleDiscountedCost);
            if (ok) {
              haptics.onAbilityShuffle();
              _showMessage('Shuffled the board 🔀');
              await _maybeShowNoMovesOffer(gameService, reason: 'after_discount_shuffle');
            } else {
              _showMessage('Not enough coins');
            }
          }
          return;
        }

        const summonCount = 4;
        const originalCost = 80;
        const discountedCost = 40;

        final action = await _showNoMovesOfferSheet(summonCount: summonCount, discountedCost: discountedCost, originalCost: originalCost);
        if (!mounted) return;

        if (action == NoMovesOfferAction.shop) {
          context.push(AppRoutes.shop);
          return;
        }

        if (action == NoMovesOfferAction.summon) {
          final audio = context.read<AudioService>();
          final haptics = context.read<HapticsService>();
          audio.playAbilityUseSound();
          final ok = await gameService.abilitySummonBurstWithGems(count: summonCount, gemCost: discountedCost);
          if (ok) {
            haptics.onSummon();
            _showMessage('Summoned new items ✨');
          } else {
            _showMessage('Couldn\'t summon (board full or not enough gems)');
          }
        }
      } catch (e) {
        debugPrint('No-moves delayed offer failed ($reason): $e');
      }
    });
  }

  Future<bool?> _showNoEnergyOfferSheet({required int energyAmount, required int currentEnergy, required int requiredEnergy}) async {
    if (!mounted || !_isOnGameBoardRoute()) return null;
    _isNoEnergySheetOpen = true;
    try {
      final shop = context.read<ShopService>();
      final priceLabel = shop.priceLabelFor('energy_100') ?? '\$0.99';
      final purchaseEnabled = true;
      return await context.read<PopupManager>().showBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => NoEnergyOfferSheet(
              energyPackAmount: energyAmount,
              currentEnergy: currentEnergy,
              requiredEnergy: requiredEnergy,
              priceLabel: priceLabel,
              purchaseEnabled: purchaseEnabled,
            ),
          );
    } catch (e) {
      debugPrint('Failed to show no-energy offer sheet: $e');
      return null;
    } finally {
      _isNoEnergySheetOpen = false;
    }
  }

  Future<void> _maybeShowNoEnergyOffer(GameService gs, {required String reason}) async {
    if (!mounted || _isNoEnergySheetOpen) return;
    if (!_isOnGameBoardRoute()) return;
    if (!gs.playerStats.hasCompletedTutorial) return;

    final availability = gs.evaluateMoveAvailability();
    final requiredEnergy = availability.minEnergyRequired ?? 1;

    // Reset episode if energy has recovered to a playable state.
    if (gs.playerStats.energy >= requiredEnergy) {
      _noEnergyOfferShownForEpisode = false;
      _cancelNoEnergyOfferTimer();
      return;
    }

    if (_noEnergyOfferShownForEpisode) return;
    if (_noEnergyOfferTimer?.isActive == true) return;

    _noEnergyOfferTimer = Timer(_noEnergyOfferDelay, () async {
      if (!mounted || _isNoEnergySheetOpen) return;
      if (!_isOnGameBoardRoute()) return;

      final gameService = context.read<GameService>();
      if (gameService.isLoading) return;
      final availabilityNow = gameService.evaluateMoveAvailability();
      final requiredEnergyNow = availabilityNow.minEnergyRequired ?? 1;
      if (gameService.playerStats.energy >= requiredEnergyNow) return;

      try {
        _noEnergyOfferShownForEpisode = true;
        _noEnergyOfferTimer = null;

        const energyAmount = 100;
        final shouldBuy = await _showNoEnergyOfferSheet(
          energyAmount: energyAmount,
          currentEnergy: gameService.playerStats.energy,
          requiredEnergy: requiredEnergyNow,
        );
        if (!mounted) return;
        if (shouldBuy == true) {
          await _buyEnergyFromOffer(energyAmount: energyAmount);
        }
      } catch (e) {
        debugPrint('No-energy delayed offer failed ($reason): $e');
      }
    });
  }

  Future<void> _buyEnergyFromOffer({required int energyAmount}) async {
    final shop = context.read<ShopService>();
    final game = context.read<GameService>();

    try {
      context.read<PopupManager>().showDialogNonBlocking(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

      final success = await shop.purchase('energy_100');
      if (!mounted) return;
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}

      if (success) {
        await game.addEnergy(energyAmount);
        if (mounted) _showCenterPopup('Energy refilled ⚡', icon: Icons.bolt);
      } else {
        if (mounted) _showMessage('Purchase failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Energy purchase from offer failed: $e');
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        _showMessage('Purchase failed. Please try again.');
      }
    }
  }

  // Helper to safely trigger rebuilds from extension methods without using the
  // protected setState outside of this State subclass.
  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  // ===================== Confetti dynamic settings =====================
  // These properties get updated right before playing confetti to reflect
  // the current combo size so the effect feels progressively punchier.
  double _confettiEmission = 0.05;
  int _confettiParticles = 30;
  double _confettiGravity = 0.2;
  double _confettiDrag = 0.05;
  double _confettiMinBlast = 3.0;
  double _confettiMaxBlast = 8.0;
  BlastDirectionality _confettiDir = BlastDirectionality.explosive;
  List<Color>? _confettiColorsCache;
  Path Function(Size size)? _confettiShape;

  void _updateConfettiForMerge({required int selectionCount, required int tier}) {
    try {
      final cs = Theme.of(context).colorScheme;
      // Stages based on how many items are merged at once
      // 4-5: subtle, 6-7: medium (circles), 8+: big (stars)
      if (selectionCount <= 5) {
        _confettiEmission = 0.03;
        _confettiParticles = 28;
        _confettiGravity = 0.28;
        _confettiDrag = 0.055;
        _confettiMinBlast = 2.0;
        _confettiMaxBlast = 6.0;
        _confettiDir = BlastDirectionality.explosive;
        _confettiShape = null; // default squares
        _confettiColorsCache = [
          cs.primary,
          cs.secondary,
          cs.tertiary,
          cs.primaryContainer,
        ];
      } else if (selectionCount <= 7) {
        _confettiEmission = 0.07;
        _confettiParticles = 46;
        _confettiGravity = 0.24;
        _confettiDrag = 0.045;
        _confettiMinBlast = 3.0;
        _confettiMaxBlast = 10.0;
        _confettiDir = BlastDirectionality.explosive;
        _confettiShape = _circlePath;
        _confettiColorsCache = [
          cs.primary,
          cs.secondary,
          cs.tertiary,
          cs.onSecondaryContainer,
          cs.onPrimary,
        ];
      } else {
        _confettiEmission = 0.12;
        _confettiParticles = 72;
        _confettiGravity = 0.22;
        _confettiDrag = 0.04;
        _confettiMinBlast = 4.0;
        _confettiMaxBlast = 14.0;
        _confettiDir = BlastDirectionality.explosive;
        _confettiShape = _starPath;
        _confettiColorsCache = [
          cs.primary,
          cs.secondary,
          cs.tertiary,
          cs.onPrimary,
          cs.onTertiaryContainer,
          cs.secondaryContainer,
        ];
      }
      debugPrint('Confetti tuned: count=$_confettiParticles emission=$_confettiEmission shape=${_confettiShape == null ? 'square' : _confettiShape == _circlePath ? 'circle' : 'star'}');
    } catch (e) {
      debugPrint('Confetti tuning failed: $e');
    }
  }

  Path _circlePath(Size size) {
    final r = size.shortestSide / 2;
    return Path()..addOval(Rect.fromCircle(center: Offset(r, r), radius: r));
  }

  Path _starPath(Size size) {
    // 5-point star
    final Path path = Path();
    final double w = size.width, h = size.height;
    final double cx = w / 2, cy = h / 2;
    final double outerR = math.min(cx, cy);
    final double innerR = outerR * 0.5;
    for (int i = 0; i < 10; i++) {
      final isEven = i % 2 == 0;
      final r = isEven ? outerR : innerR;
      final a = -math.pi / 2 + (i * math.pi / 5);
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  void _onItemTap(GameItem item, GameService gameService) {
    _registerUserInteraction();
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
    _registerUserInteraction();
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
    final selectionCount = itemsToMerge.length;

    if (gameService.playerStats.energy <= 0) {
      _showMessage('Not enough energy ⚡');
      unawaited(_maybeShowNoEnergyOffer(gameService, reason: 'merge_attempt'));
      return;
    }
    
    if (!gameService.canMerge(itemsToMerge)) {
      _handleInvalidMergeAttempt();
      return;
    }

    // Play advanced merge animation before mutating state
    await _playMergeAnimation(itemsToMerge);
    final prevLevel = gameService.currentLevel;
    final newItem = await gameService.mergeItems(
      itemsToMerge,
      preferredTargetItemId: _selectedItem?.id,
    );
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
      // Only trigger screen-wide effects for merges > 3, and vary style every +2 over 3
      if (selectionCount > 3) {
        if (!reducedMotion) {
          _updateConfettiForMerge(selectionCount: selectionCount, tier: newItem.tier);
          _confettiController.play();
        }
        // Emit local particle burst at target (scaled by tier, reduced for low-motion)
        final center = _targetCenter;
        if (center != null) {
          final int base = reducedMotion ? 10 : 24;
          final int perTier = reducedMotion ? 2 : 6;
          final int count = (base + newItem.tier * perTier).clamp(10, 160);
          // Variant groups: (4-5)->0, (6-7)->1, (8-9)->2, ...
          final int variant = ((selectionCount - 4) ~/ 2).clamp(0, 1000);
          debugPrint('Particle burst variant=$variant for selectionCount=$selectionCount');
          _particleKey.currentState?.burst(center, count: count, variant: variant);
          _triggerScreenPulse(center: center, tier: newItem.tier, reducedMotion: reducedMotion);
        }
      }
      _showComboBanner(tier: newItem.tier, selectionCount: itemsToMerge.length);
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

      // Post-merge board evaluation: decide which (if any) offer/nudge to show.
      await _runPostMergeBoardCheck(gameService);
    }
  }

  Future<void> _runPostMergeBoardCheck(GameService gs) async {
    if (!mounted) return;
    final availability = gs.evaluateMoveAvailability();

    // If the player is blocked by energy, don't show “no moves” UX.
    if (availability.boardHasAnyMoves && !availability.hasSufficientEnergy) {
      unawaited(_maybeShowNoEnergyOffer(gs, reason: 'after_merge'));
      return;
    }

    if (!availability.boardHasAnyMoves) {
      await _maybeShowNoMovesOffer(gs, reason: 'after_merge_no_moves');
      return;
    }

    // If there are no standard 3+ merges, but Power Merge could still help,
    // give a gentle nudge (and avoid opening the no-moves sheet).
    if (availability.hasOnlyPowerMoves && availability.powerMergeCharges > 0) {
      _showCenterPopup('No 3-merges left — try Power Merge ⚡', icon: Icons.flash_on);
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
    unawaited(context.read<PopupManager>().showCenterToast(context, message: message, icon: Icons.auto_awesome));
  }

  void _showCenterPopup(String message, {IconData? icon, Duration duration = const Duration(milliseconds: 1600)}) {
    if (!mounted) return;
    unawaited(context.read<PopupManager>().showCenterToast(context, message: message, icon: icon, duration: duration));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<GameService, AudioService, AchievementService, QuestService>(
      builder: (context, gameService, audioService, achievementService, questService, child) {
        // After a refresh, the service can briefly report “no moves” while
        // Firestore/local state finishes loading. Run a one-time check once
        // loading completes to sync our debounce state.
        unawaited(_runInitialMoveCheckIfNeeded(gameService));

        // If the board becomes stuck at any point (including via remote sync),
        // offer a discounted summon once per board state.
        if (!_isNoMovesSheetOpen && _didInitialMoveCheck && !gameService.isLoading && gameService.playerStats.hasCompletedTutorial) {
          final sig = _computeNoMovesSignature(gameService);
          if (_lastNoMovesSignature != sig && !gameService.hasAnyStandardMergeMoves()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_maybeShowNoMovesOffer(gameService, reason: 'build_watch'));
            });
          }
        }

        // If the board changes while a hint is active (e.g. remote sync, ability
        // usage, etc.), ensure we never keep showing a “partial” hint.
        if (_hintedItems.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Only count tiles that are both present AND visible (not currently
            // hidden by merge/spawn animations). If fewer than 3 remain visible,
            // the hint is misleading.
            final visibleCount = _visibleBoardItems(gameService, excludedIds: _animatingIds).where((gi) => _hintedItems.contains(gi.id)).length;
            if (visibleCount < 3) {
              setState(() => _hintedItems.clear());
            }
          });
        }

        // After the frame, check for newly spawned items to animate
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ev = gameService.takeLastSpawnEvent();
          if (ev != null) {
            _playSpawnAnimation(ev.items, originX: ev.originX, originY: ev.originY);
          }
        });
        if (gameService.isLoading) {
          final hasNetwork = context.watch<ConnectivityService>().hasNetwork;
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading your game...', style: Theme.of(context).textTheme.titleMedium),
                  if (!hasNetwork) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.read<GameService>().forceLocalFallback(),
                      icon: Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.primary),
                      label: Text('Continue offline', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final showTutorial = !gameService.playerStats.hasCompletedTutorial;

        return Scaffold(
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _registerUserInteraction(),
            onPointerMove: (_) => _registerUserInteraction(),
            child: Stack(
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
                  // The game UI needs top/side insets, but applying a bottom
                  // SafeArea to the whole Column creates an empty “gap” under
                  // the bottom controls (notably visible on iOS with the home
                  // indicator). We instead handle the bottom inset inside the
                  // bottom bar itself.
                  bottom: false,
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
                  blastDirectionality: _confettiDir,
                  minBlastForce: _confettiMinBlast,
                  maxBlastForce: _confettiMaxBlast,
                  particleDrag: _confettiDrag,
                  emissionFrequency: _confettiEmission,
                  numberOfParticles: _confettiParticles,
                  gravity: _confettiGravity,
                  minimumSize: const Size(6, 6),
                  maximumSize: const Size(14, 14),
                  colors: _confettiColorsCache ?? [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.tertiary,
                  ],
                  createParticlePath: _confettiShape,
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
                        isHighlighted: _highlightedItems.contains(item.id) || _hintedItems.contains(item.id),
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
                        _registerUserInteraction();
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
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
                             await _maybeShowNoMovesOffer(gameService, reason: 'after_summon');
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
                           if (ok) { context.read<HapticsService>().onAbilityDuplicate(); _showMessage('Duplicated item ➕'); await _maybeShowNoMovesOffer(gameService, reason: 'after_duplicate'); }
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
                             await _maybeShowNoMovesOffer(gameService, reason: 'after_clear');
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
                           if (ok) { context.read<HapticsService>().onAbilityShuffle(); _showMessage('Shuffled the board 🔀'); await _maybeShowNoMovesOffer(gameService, reason: 'after_shuffle'); }
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
