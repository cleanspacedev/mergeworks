 import 'package:flutter/foundation.dart';
 import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/models/player_stats.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/services/game_platform_service.dart';
import 'package:mergeworks/services/game_platform_config.dart';
import 'dart:math';

@immutable
class MoveAvailability {
  const MoveAvailability({
    required this.currentEnergy,
    required this.minEnergyRequired,
    required this.hasSufficientEnergy,
    required this.boardHasStandardMoves,
    required this.boardHasAnyMoves,
    required this.hasOnlyPowerMoves,
    required this.powerMergeCharges,
  });

  /// Player's current energy.
  final int currentEnergy;

  /// The minimum energy required to perform *some* legal move on the current
  /// board.
  ///
  /// `null` means there are no legal moves on the board regardless of energy.
  ///
  /// NOTE: Today, merges cost 1 energy, so this will be `1` whenever
  /// [boardHasAnyMoves] is true. This is intentionally modeled as a value so
  /// the UI can evolve without being hard-coded to “energy == 0”.
  final int? minEnergyRequired;

  /// Whether the player has enough energy to perform at least one legal move.
  final bool hasSufficientEnergy;

  /// Whether the board has a standard 3+ merge available, ignoring energy.
  final bool boardHasStandardMoves;

  /// Whether the board has *any* merge available under current rules, ignoring
  /// energy (i.e. may include 2-merges when Power Merge charges exist).
  final bool boardHasAnyMoves;
  final bool hasOnlyPowerMoves;
  final int powerMergeCharges;
}

class GameService extends ChangeNotifier {
  // Watchdog to guarantee we never stay stuck on loading (e.g., iOS networking stalls)
  Timer? _initWatchdog;
  FirebaseService? _firebaseService;
  GamePlatformService? _platformService;

  String? get _userId => _firebaseService?.userId;
  // Unique ID generator sequence to avoid duplicate IDs when creating items rapidly
  int _idSeq = 0;
  String _makeId(int tier) => 'gi_${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}_t$tier';
  final Random _rand = Random();
  
  // Ephemeral ability state (not persisted)
  int _powerMergeCharges = 0;
  
  PlayerStats _playerStats = PlayerStats();
  List<GameItem> _gridItems = [];
  bool _isLoading = false;
  // Init state guards to avoid re-entrancy and post-fallback re-init
  bool _initInProgress = false;
  bool _initFinalized = false; // set true after a successful remote init OR local fallback

  PlayerStats get playerStats => _playerStats;
  List<GameItem> get gridItems => _gridItems;
  bool get isLoading => _isLoading;
  int get powerMergeCharges => _powerMergeCharges;

  /// Snapshot of whether the player has any merge moves available.
  ///
  /// This is intended for UX decisions (popups, offers) and is computed from the
  /// current board state + energy + power-merge rules.
  MoveAvailability evaluateMoveAvailability() {
    try {
      final currentEnergy = _playerStats.energy;

      // Important: move existence should be computed independently from energy.
      // Otherwise UI can incorrectly classify “no moves” as “no energy”, or
      // vice-versa.
      final boardHasStandardMoves = hasAnyStandardMergeMoves(ignoreEnergy: true);
      final boardHasAnyMoves = hasAnyMergeMoves(ignoreEnergy: true);
      final hasOnlyPowerMoves = boardHasAnyMoves && !boardHasStandardMoves;

      // Today, any merge costs 1 energy.
      final minEnergyRequired = boardHasAnyMoves ? 1 : null;
      final hasSufficientEnergy = minEnergyRequired == null ? true : currentEnergy >= minEnergyRequired;

      return MoveAvailability(
        currentEnergy: currentEnergy,
        minEnergyRequired: minEnergyRequired,
        hasSufficientEnergy: hasSufficientEnergy,
        boardHasStandardMoves: boardHasStandardMoves,
        boardHasAnyMoves: boardHasAnyMoves,
        hasOnlyPowerMoves: hasOnlyPowerMoves,
        powerMergeCharges: _powerMergeCharges,
      );
    } catch (e) {
      debugPrint('Failed to evaluate move availability: $e');
      return MoveAvailability(
        currentEnergy: _playerStats.energy,
        minEnergyRequired: null,
        hasSufficientEnergy: true,
        boardHasStandardMoves: false,
        boardHasAnyMoves: false,
        hasOnlyPowerMoves: false,
        powerMergeCharges: _powerMergeCharges,
      );
    }
  }

  // Ephemeral UI event: recently spawned items with an origin for animations
  SpawnEvent? _lastSpawnEvent;
  SpawnEvent? get lastSpawnEvent => _lastSpawnEvent;
  SpawnEvent? takeLastSpawnEvent() {
    final ev = _lastSpawnEvent;
    _lastSpawnEvent = null;
    return ev;
  }
  void _recordSpawnEvent(List<GameItem> items, {int? originX, int? originY}) {
    if (items.isEmpty) return;
    final ox = originX ?? (gridSize ~/ 2);
    final oy = originY ?? (gridSize ~/ 2);
    _lastSpawnEvent = SpawnEvent(items: List<GameItem>.from(items), originX: ox, originY: oy);
  }

  /// Public emergency escape hatch: immediately proceed with local data if init is stuck
  void forceLocalFallback() {
    if (_initFinalized) return; // already finalized, nothing to do
    // Allow forcing fallback even if _isLoading was briefly toggled by async
    debugPrint('Init fallback requested by UI. Seeding local state and continuing.');
    try {
      _initWatchdog?.cancel();
      _initWatchdog = null;
    } catch (_) {}
    _initializeStarterItems();
    _ensureTargetPopulation();
    // Mark initialization as finalized to prevent any later auth notifications from re-triggering init
    _initInProgress = false;
    _initFinalized = true;
    _isLoading = false;
    notifyListeners();
  }
  
  // Permanent collection progress: store discovered tiers as 'tier_<n>' keys in playerStats.discoveredItems
  Set<int> get _discoveredTiers {
    final set = <int>{};
    for (final s in _playerStats.discoveredItems) {
      if (s.startsWith('tier_')) {
        final p = int.tryParse(s.split('_').last);
        if (p != null) set.add(p);
      }
    }
    return set;
  }
  int get discoveredTierCount => _discoveredTiers.length;
  
  void setFirebaseService(FirebaseService service) {
    _firebaseService = service;
    _firebaseService?.addListener(_onAuthStateChanged);
    if (_firebaseService?.isInitialized == true && _firebaseService?.isAuthenticated == true) {
      initialize();
    }
  }
  void setPlatformService(GamePlatformService service) {
    _platformService = service;
  }
  
  void _onAuthStateChanged() {
    // Only initialize once per app session, and avoid re-entrancy
    if (_firebaseService?.isAuthenticated == true && !_initFinalized && !_initInProgress) {
      initialize();
    }
  }

  static const int gridSize = 6;

  // Level templates (for naming/emoji generation only). This is NOT used for player
  // progression anymore.
  // We keep the original content cadence for template generation, but player level
  // progression below uses a fast-early, slow-late curve based on discovered tiers.
  static final List<int> _levelTierCounts = [18, 10, 10, 10, 10, 10]; // extendable
  static late final Map<int, Map<String, dynamic>> _itemTemplates = _buildTemplates();
  static int get totalTiers => _itemTemplates.length;

  // ---------------------------------------------------------------------------
  // LEVEL PROGRESSION
  // ---------------------------------------------------------------------------
  // The player's level is derived from collection progress (unique tiers
  // discovered). Early levels should be reachable quickly.
  //
  // We intentionally make Level 4 more reachable than the older triangular curve
  // (which required 10 unique tiers). New early thresholds:
  //  L1: 1 tier
  //  L2: 3 tiers
  //  L3: 5 tiers
  //  L4: 8 tiers
  // After that we grow by (level-1) tiers each level:
  //  L5: 12, L6: 17, L7: 23, ...
  static const List<int> _earlyLevelMaxTierThresholds = [1, 3, 5, 8];

  /// Returns the max discovered-tier count that still maps to [level].
  ///
  /// Example: if this returns 8 for level 4, then discovering 9 tiers moves you
  /// to level 5.
  static int tierThresholdForLevel(int level) {
    if (level <= 1) return 1;
    if (level <= _earlyLevelMaxTierThresholds.length) return _earlyLevelMaxTierThresholds[level - 1];
    int threshold = _earlyLevelMaxTierThresholds.last;
    for (int l = _earlyLevelMaxTierThresholds.length + 1; l <= level; l++) {
      threshold += (l - 1);
      if (threshold > 999999) break;
    }
    return threshold;
  }

  /// Returns the current level for a given number of discovered tiers.
  static int levelForDiscoveredTiers(int discoveredTiers) {
    final count = discoveredTiers <= 0 ? 1 : discoveredTiers;
    // Find the first level whose threshold contains count.
    int level = 1;
    while (count > tierThresholdForLevel(level)) {
      level++;
      if (level > 999) break;
    }
    return level;
  }
  // Link levels to collection progress: your level is determined by how many unique tiers
  // you have discovered in the collection book (not just the highest on-board tier)
  int get currentLevel {
    return levelForDiscoveredTiers(discoveredTierCount);
  }

  /// How many additional unique tiers are required to reach the next level.
  int get tiersRemainingToNextLevel {
    final nextRequired = tierThresholdForLevel(currentLevel) + 1;
    final discovered = discoveredTierCount <= 0 ? 1 : discoveredTierCount;
    return (nextRequired - discovered).clamp(0, 1 << 30);
  }

  static Map<int, Map<String, dynamic>> _buildTemplates() {
    final Map<int, Map<String, dynamic>> base = {};
    // Base 18 matching existing progression for continuity
    final List<Map<String, String>> base18 = [
      {'n': 'Spark', 'e': '✨', 'd': 'A tiny spark of magic'},
      {'n': 'Glow', 'e': '💫', 'd': 'A gentle magical glow'},
      {'n': 'Shimmer', 'e': '🌟', 'd': 'Shimmering energy'},
      {'n': 'Crystal', 'e': '💎', 'd': 'A small magic crystal'},
      {'n': 'Gem', 'e': '💠', 'd': 'A glowing magical gem'},
      {'n': 'Orb', 'e': '🔮', 'd': 'A mystical orb'},
      {'n': 'Rune', 'e': '🗿', 'd': 'An ancient rune stone'},
      {'n': 'Amulet', 'e': '📿', 'd': 'A magical amulet'},
      {'n': 'Wand', 'e': '🪄', 'd': 'A powerful wand'},
      {'n': 'Staff', 'e': '⚡', 'd': 'A lightning staff'},
      {'n': 'Crown', 'e': '👑', 'd': 'A mystical crown'},
      {'n': 'Scepter', 'e': '🔱', 'd': 'A royal scepter'},
      {'n': 'Dragon', 'e': '🐉', 'd': 'A magical dragon'},
      {'n': 'Phoenix', 'e': '🔥', 'd': 'A legendary phoenix'},
      {'n': 'Unicorn', 'e': '🦄', 'd': 'A mythical unicorn'},
      {'n': 'Portal', 'e': '🌀', 'd': 'A dimensional portal'},
      {'n': 'Galaxy', 'e': '🌌', 'd': 'A pocket galaxy'},
      {'n': 'Infinity', 'e': '♾️', 'd': 'The essence of infinity'},
    ];
    for (int i = 0; i < base18.length; i++) {
      base[i + 1] = {
        'name': base18[i]['n']!,
        'emoji': base18[i]['e']!,
        'description': base18[i]['d']!,
      };
    }
    // Generate subsequent tiers algorithmically using themed emoji pools
    final List<List<String>> emojiPools = [
      // Level 2: Elements/Alchemy
      ['🪨', '🌿', '💧', '🔥', '🌪️', '⚗️', '🧪', '🪙', '🛡️', '🗡️'],
      // Level 3: Space/Tech
      ['🛰️', '🛸', '🧭', '🔭', '⚙️', '💽', '🧬', '🧲', '🔋', '📡'],
      // Level 4: Nature/Myth
      ['🍃', '🌙', '🦋', '🌈', '🪷', '🦅', '🐺', '🦀', '🌊', '⛰️'],
      // Level 5: Arcane/Runes
      ['📜', '🔮', '🪄', '🧿', '☯️', '🕯️', '💠', '🪬', '🔰', '🧿'],
      // Level 6: Celestial
      ['⭐', '🌟', '✨', '🌠', '☄️', '🌞', '🌛', '🪐', '🌌', '🌤️'],
    ];
    int tier = base18.length + 1;
    for (int lvlIndex = 0; lvlIndex < emojiPools.length; lvlIndex++) {
      final pool = emojiPools[lvlIndex];
      final int count = (lvlIndex < _levelTierCounts.length - 1) ? _levelTierCounts[lvlIndex + 1] : 10;
      for (int i = 0; i < count; i++) {
        final emoji = pool[i % pool.length];
        base[tier] = {
          'name': 'Relic ${tier.toString().padLeft(2, '0')}',
          'emoji': emoji,
          'description': 'A rare relic of level ${lvlIndex + 2}',
        };
        tier++;
      }
    }
    return base;
  }

  Future<void> initialize() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) {
      debugPrint('Skipping GameService init: Firebase not ready');
      return;
    }
    if (_initFinalized) {
      debugPrint('GameService init skipped: already finalized.');
      return;
    }
    if (_initInProgress) {
      debugPrint('GameService init already in progress, skipping re-entry.');
      return;
    }
    _initInProgress = true;
    
    _isLoading = true;
    notifyListeners();

    // Start watchdog: if we haven't completed init in 12s, force local fallback
    try {
      _initWatchdog?.cancel();
    } catch (_) {}
    _initWatchdog = Timer(const Duration(seconds: 12), () {
      debugPrint('Initialization watchdog fired after 12s. Forcing local fallback.');
      _initializeStarterItems();
      _ensureTargetPopulation();
      _initInProgress = false;
      _initFinalized = true;
      _isLoading = false;
      notifyListeners();
    });

    try {
      final userId = _userId;
      if (userId == null || userId.isEmpty) {
        // This can happen transiently on web during early auth initialization.
        // Fail safe: stop loading and let the auth listener retry shortly.
        debugPrint('GameService init aborted: userId is null/empty despite isAuthenticated=true');
        _initInProgress = false;
        _isLoading = false;
        try {
          _initWatchdog?.cancel();
          _initWatchdog = null;
        } catch (_) {}
        notifyListeners();
        return;
      }
      
      // Load player stats from Firestore
      final statsDoc = await _firebaseService!.firestore
              .collection('player_stats')
              .doc(userId)
              .get()
              .timeout(const Duration(seconds: 6));
      
      if (statsDoc.exists) {
        _playerStats = PlayerStats.fromJson(statsDoc.data()!);
      } else {
        // Create new player stats
        _playerStats = PlayerStats(userId: userId);
        try {
          await _savePlayerStats().timeout(const Duration(seconds: 5));
        } on TimeoutException {
          debugPrint('Save player stats timed out (init). Will retry later.');
        } catch (e) {
          debugPrint('Save player stats failed (init): $e');
        }
      }

      // Load grid items from Firestore (user-scoped subcollection preferred)
      List<QueryDocumentSnapshot<Map<String, dynamic>>> itemDocs = [];
      try {
        final subColSnap = await _firebaseService!.firestore
                .collection('player_stats')
                .doc(userId)
                .collection('grid_items')
                .get()
                .timeout(const Duration(seconds: 6));
        itemDocs = subColSnap.docs;
        debugPrint('Loaded ${itemDocs.length} grid items from subcollection.');
      } on TimeoutException {
        debugPrint('Timed out loading subcollection grid items');
      } catch (e) {
        debugPrint('Failed to load subcollection grid items: $e');
      }

      // Backward-compat: if subcollection is empty, fall back to old top-level collection
      if (itemDocs.isEmpty) {
        try {
          final legacySnap = await _firebaseService!.firestore
                  .collection('grid_items')
                  .where('user_id', isEqualTo: userId)
                  .get()
                  .timeout(const Duration(seconds: 6));
          itemDocs = legacySnap.docs;
          if (itemDocs.isNotEmpty) {
            debugPrint('Loaded ${itemDocs.length} grid items from legacy top-level collection. Will migrate to subcollection on next save.');
          }
        } on TimeoutException {
          debugPrint('Timed out loading legacy grid items (top-level)');
        } catch (e) {
          debugPrint('Failed to load legacy grid items (top-level): $e');
        }
      }

      _gridItems = itemDocs
          .map((doc) => GameItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sanitize: ensure all item IDs are unique (older versions might have duplicates)
      final seen = <String>{};
      bool changed = false;
      for (var i = 0; i < _gridItems.length; i++) {
        final id = _gridItems[i].id;
        if (seen.contains(id)) {
          // Reassign a fresh unique id
          final replacement = _gridItems[i].copyWith(id: _makeId(_gridItems[i].tier));
          _gridItems[i] = replacement;
          changed = true;
        } else {
          seen.add(id);
        }
      }
      if (changed) {
        debugPrint('Detected duplicate item IDs on load. Regenerated unique IDs.');
        try {
          await _saveState().timeout(const Duration(seconds: 5));
        } on TimeoutException {
          debugPrint('Save state timed out after ID fix. Will retry later.');
        } catch (e) {
          debugPrint('Save state failed after ID fix: $e');
        }
      }

      if (_gridItems.isEmpty) {
        debugPrint('Grid empty on load. Seeding starter items...');
        _initializeStarterItems();
      } else if (!_hasAnyImmediateTriple()) {
        debugPrint('No valid merges detected on load. Injecting a merge opportunity...');
        _injectMergeOpportunity();
      }

      // Ensure collection discoveries persist: mark any tiers currently present as discovered
      final presentTiers = _gridItems.map((i) => i.tier).toSet();
      final discovered = Set<String>.from(_playerStats.discoveredItems);
      bool discoveredChanged = false;
      for (final t in presentTiers) {
        final key = 'tier_$t';
        if (!discovered.contains(key)) {
          discovered.add(key);
          discoveredChanged = true;
        }
      }
      if (discoveredChanged) {
        _playerStats = _playerStats.copyWith(discoveredItems: discovered.toList(), updatedAt: DateTime.now());
        try {
          await _savePlayerStats().timeout(const Duration(seconds: 5));
        } on TimeoutException {
          debugPrint('Save player stats timed out (discoveries).');
        } catch (e) {
          debugPrint('Save player stats failed (discoveries): $e');
        }
      }

      // Ensure the board feels lively: keep a minimum population that scales with level
      _ensureTargetPopulation();

      _updateEnergy();
      await _checkDailyLogin();
      // Submit initial scores to platform leaderboards (best-effort)
      try {
        await _platformService?.submitAllScores(
          totalMerges: _playerStats.totalMerges,
          highestTier: _playerStats.highestTier,
          level: currentLevel,
        );
      } catch (e) {
        debugPrint('Platform score submit on init failed: $e');
      }
    } on TimeoutException catch (e) {
      debugPrint('Initialization timed out: $e');
      _initializeStarterItems();
      _ensureTargetPopulation();
    } catch (e) {
      debugPrint('Failed to initialize game: $e');
      _initializeStarterItems();
      _ensureTargetPopulation();
    } finally {
      try {
        _initWatchdog?.cancel();
      } catch (_) {}
      _initWatchdog = null;
      _initInProgress = false;
      _initFinalized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _initializeStarterItems() {
    // Seed with a guaranteed merge: three tier-1 items adjacent in an L-shape
    _gridItems = [
      _createItem(1, 1, 1),
      _createItem(1, 2, 1),
      _createItem(1, 2, 2),
    ];
    // Add a handful of extra low tiers to make the board feel populated
    // Use ambient tier rules so early boards have a mix (Level 1–3: tiers 1–4).
    _fillAmbientAnywhere(count: 12);

    // Safety: keep at least one easy triple available (tier 1 at the start).
    if (_countOfTier(1) < 3) {
      _fillMatchingLowest(count: 3 - _countOfTier(1));
    }
    _saveState();
  }

  // Target population scales by current level to keep screens feeling rich
  void _ensureTargetPopulation() {
    final lvl = currentLevel;
    final target = 18 + (lvl - 1) * 4; // +4 items per level
    final minCount = target.clamp(18, 32); // cap to avoid overcrowding a 6x6 grid
    final deficit = minCount - _gridItems.length;
    if (deficit > 0) {
      // Fill with a MIX of tiers (fresh roll per item) using ambient spawn rules.
      _fillAmbientAnywhere(count: deficit);

      // Guarantee that there are at least 3 of the current lowest tier.
      final currentLowest = _lowestNonWildcardTierOnBoard();
      if (_countOfTier(currentLowest) < 3) {
        _fillMatchingLowest(count: 3 - _countOfTier(currentLowest));
      }
      _saveState();
    }
  }

  // Determine the lowest non-wildcard tier currently on the board; defaults to 1
  int _lowestNonWildcardTierOnBoard() {
    final tiers = _gridItems.where((i) => !i.isWildcard).map((i) => i.tier).toList();
    if (tiers.isEmpty) return 1;
    tiers.sort();
    return tiers.first;
  }

  // Determine the highest non-wildcard tier currently on the board; defaults to 1
  int _highestNonWildcardTierOnBoard() {
    final tiers = _gridItems.where((i) => !i.isWildcard).map((i) => i.tier).toList();
    if (tiers.isEmpty) return 1;
    tiers.sort();
    return tiers.last;
  }

  void _maybeAutoDiscoverTier(int tier) {
    // Early-game variety: Levels 1–3 can "auto-discover" tiers 1–4.
    if (currentLevel > 3) return;
    final key = 'tier_$tier';
    if (_playerStats.discoveredItems.contains(key)) return;
    final discovered = List<String>.from(_playerStats.discoveredItems)..add(key);
    final newHighest = tier > _playerStats.highestTier ? tier : _playerStats.highestTier;
    _playerStats = _playerStats.copyWith(discoveredItems: discovered, highestTier: newHighest, updatedAt: DateTime.now());
  }

  int _ambientSpawnTier() {
    // Levels 1–3: spawn a random tier 1–4 (auto-discover for onboarding variety)
    if (currentLevel <= 3) {
      final maxTier = min(4, _itemTemplates.length).toInt();
      return 1 + _rand.nextInt(maxTier);
    }

    // Later: spawn between 1–4 tiers below the current highest tier on the board
    final highest = _highestNonWildcardTierOnBoard();
    final delta = 1 + _rand.nextInt(4); // 1..4
    // Keep this pure-int math (avoid `clamp()` returning `num`).
    final int upper = highest <= 1 ? 1 : (highest - 1);
    final int raw = highest - delta;
    if (raw < 1) return 1;
    if (raw > upper) return upper;
    return raw;
  }

  int _countOfTier(int tier) => _gridItems.where((i) => !i.isWildcard && i.tier == tier).length;

  List<GameItem> _fillAmbientAnywhere({required int count}) {
    final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
    final allSlots = <Map<String, int>>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (!occupied.contains('${x}_$y')) allSlots.add({'x': x, 'y': y});
      }
    }
    allSlots.shuffle(_rand);
    final created = <GameItem>[];
    for (final slot in allSlots) {
      if (created.length >= count) break;
      final tier = _ambientSpawnTier();
      final it = _createItem(tier, slot['x']!, slot['y']!);
      _maybeAutoDiscoverTier(tier);
      _gridItems.add(it);
      created.add(it);
    }
    return created;
  }

  // Fill the board with items that MATCH the current lowest tier, and ensure
  // there are always at least 3 of that tier on the board.
  List<GameItem> _fillMatchingLowest({required int count}) {
    final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
    int added = 0;
    // Try to place near top-left scanning order but choose slots randomly for variety
    final allSlots = <Map<String, int>>[];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (!occupied.contains('${x}_$y')) allSlots.add({'x': x, 'y': y});
      }
    }
    allSlots.shuffle(_rand);
    final List<GameItem> created = [];
    final targetTier = _lowestNonWildcardTierOnBoard();
    // Ensure we will reach at least 3 of the lowest tier.
    for (final slot in allSlots) {
      if (added >= count) break;
      final item = _createItem(targetTier, slot['x']!, slot['y']!);
      _gridItems.add(item);
      created.add(item);
      added++;
    }

    // If we still don't have a triple, and there are empty slots, top up to reach 3.
    if (_countOfTier(targetTier) < 3) {
      final shortBy = 3 - _countOfTier(targetTier);
      if (shortBy > 0) {
        // Recurse once with a bounded count to fill remaining
        created.addAll(_fillMatchingLowest(count: shortBy));
      }
    }
    return created;
  }

  // After a successful merge, sometimes spawn extra low-tier items near the merge location
  void _maybeSpawnLowerTiersAround(int centerX, int centerY) {
    final lvl = currentLevel;
    final chance = (0.6 + 0.05 * (lvl - 1)).clamp(0.6, 0.9);
    if (_rand.nextDouble() < chance) {
      // Add 2-4 items on higher levels, 1-3 on level 1
      final base = (lvl > 1) ? 2 : 1;
      final span = (lvl > 2) ? 3 : 2; // widen range slightly on later levels
      final toAdd = base + _rand.nextInt(span);
      final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();

      List<Map<String, int>> nearbyEmpties(int x, int y) {
        final res = <Map<String, int>>[];
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;
            if (!occupied.contains('${nx}_${ny}')) res.add({'x': nx, 'y': ny});
          }
        }
        return res;
      }

      final local = nearbyEmpties(centerX, centerY);
      local.shuffle(_rand);
      int placed = 0;
      final List<GameItem> spawned = [];

      for (final slot in local) {
        if (placed >= toAdd) break;
        final targetTier = _ambientSpawnTier();
        final it = _createItem(targetTier, slot['x']!, slot['y']!);
        _maybeAutoDiscoverTier(targetTier);
        _gridItems.add(it);
        spawned.add(it);
        placed++;
      }

      if (placed < toAdd) {
        // Fallback: fill anywhere using the same ambient tier rules
        final extra = _fillAmbientAnywhere(count: toAdd - placed);
        spawned.addAll(extra);
      }

      // Guarantee that there are at least 3 of the current lowest tier
      final currentLowest = _lowestNonWildcardTierOnBoard();
      if (_countOfTier(currentLowest) < 3) {
        _fillMatchingLowest(count: 3 - _countOfTier(currentLowest));
      }

      if (spawned.isNotEmpty) {
        // Let UI animate these new items from the merge center
        _recordSpawnEvent(spawned, originX: centerX, originY: centerY);
      }
    }

    // Also maintain overall density after each merge
    _ensureTargetPopulation();
  }

  bool _hasAnyImmediateTriple() {
    for (final item in _gridItems) {
      if (item.gridX == null || item.gridY == null) continue;
      final neighbors = getItemsInRange(item.gridX!, item.gridY!, 1)
          .where((i) => i.tier == item.tier)
          .toList();
      // including the item itself must be >= 3
      if (neighbors.length + 1 >= 3) return true;
    }
    return false;
  }

  void _injectMergeOpportunity() {
    // Try to place two matching items next to an existing one, if space allows
    final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();

    List<Map<String, int>> emptyNeighborsOf(int x, int y) {
      final coords = <Map<String, int>>[];
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;
          if (!occupied.contains('${nx}_${ny}')) coords.add({'x': nx, 'y': ny});
        }
      }
      return coords;
    }

    for (final anchor in _gridItems) {
      if (anchor.gridX == null || anchor.gridY == null) continue;
      final empties = emptyNeighborsOf(anchor.gridX!, anchor.gridY!);
      if (empties.length >= 2 && anchor.tier < _itemTemplates.length) {
        final e1 = empties[0];
        final e2 = empties[1];
        final aTier = anchor.tier;
        _gridItems.add(_createItem(aTier, e1['x']!, e1['y']!));
        _gridItems.add(_createItem(aTier, e2['x']!, e2['y']!));
        debugPrint('Injected two items of tier $aTier near (${anchor.gridX}, ${anchor.gridY}).');
        _saveState();
        return;
      }
    }

    // Fallback: place starter L-shape in the first 2x2 block with space
    for (int y = 0; y < gridSize - 1; y++) {
      for (int x = 0; x < gridSize - 1; x++) {
        final slots = ['${x}_${y}', '${x + 1}_${y}', '${x + 1}_${y + 1}'];
        final allEmpty = slots.every((s) => !occupied.contains(s));
        if (allEmpty) {
          _gridItems.addAll([
            _createItem(1, x, y),
            _createItem(1, x + 1, y),
            _createItem(1, x + 1, y + 1),
          ]);
          debugPrint('Fallback inject: placed starter L-shape at ($x,$y).');
          _saveState();
          return;
        }
      }
    }
    debugPrint('Unable to inject a merge opportunity (board too full).');
  }

  GameItem _createItem(int tier, int x, int y) {
    final template = _itemTemplates[tier]!;
    return GameItem(
      id: _makeId(tier),
      name: template['name'],
      tier: tier,
      emoji: template['emoji'],
      description: template['description'],
      gridX: x,
      gridY: y,
      isDiscovered: true,
    );
  }

  void _updateEnergy() {
    final now = DateTime.now();
    final elapsed = now.difference(_playerStats.lastEnergyUpdate);
    final minutesElapsed = elapsed.inMinutes;
    final energyToAdd = minutesElapsed ~/ 5;

    if (energyToAdd > 0) {
      final newEnergy = (_playerStats.energy + energyToAdd).clamp(0, _playerStats.maxEnergy);
      _playerStats = _playerStats.copyWith(
        energy: newEnergy,
        lastEnergyUpdate: now,
        updatedAt: now,
      );
      _saveState();
    }
  }

  Future<void> _checkDailyLogin() async {
    final now = DateTime.now();
    final lastLogin = _playerStats.lastLoginDate;

    if (lastLogin == null) {
      _playerStats = _playerStats.copyWith(
        loginStreak: 1,
        lastLoginDate: now,
        updatedAt: now,
      );
      _saveState();
      return;
    }

    final daysSinceLogin = now.difference(lastLogin).inDays;
    if (daysSinceLogin == 1) {
      _playerStats = _playerStats.copyWith(
        loginStreak: _playerStats.loginStreak + 1,
        lastLoginDate: now,
        updatedAt: now,
      );
      _saveState();
    } else if (daysSinceLogin > 1) {
      _playerStats = _playerStats.copyWith(
        loginStreak: 1,
        lastLoginDate: now,
        updatedAt: now,
      );
      _saveState();
    }
  }

  bool canMerge(List<GameItem> items) {
    if (items.isEmpty) return false;
    // Separate wildcards from regular items
    final nonWild = items.where((i) => !i.isWildcard).toList();
    final wildCount = items.length - nonWild.length;
    if (nonWild.isEmpty) return false; // need at least one real item

    final baseTier = nonWild.first.tier;
    final sameTier = nonWild.every((item) => item.tier == baseTier);
    if (!sameTier) return false;
    if (baseTier >= _itemTemplates.length) return false;

    final totalCount = nonWild.length + wildCount;
    if (totalCount >= 3) return _playerStats.energy > 0; // require energy to proceed
    // Allow 2-item merge (including wildcard + one item) if a power-merge charge is available
    if (totalCount == 2 && _powerMergeCharges > 0) return _playerStats.energy > 0;
    return false;
  }

  /// Returns true if there exists at least one mergeable group on the board
  /// under the current rules (wildcards allowed, and 2-item merges allowed when
  /// [powerMergeCharges] > 0).
  ///
  /// This is used for UX decisions (e.g. hint prompts, “no moves” prompts).
  bool hasAnyMergeMoves({bool ignoreEnergy = false}) => _hasAnyMergeMovesInternal(
    minNeeded: _powerMergeCharges > 0 ? 2 : 3,
    ignoreEnergy: ignoreEnergy,
  );

  /// Returns true if there exists at least one *standard* 3-item merge on the
  /// board (wildcards allowed), regardless of [powerMergeCharges].
  ///
  /// This is used for UX that specifically refers to “being stuck” in the
  /// default game flow. If the player has Power Merge charges, they may still
  /// be able to do 2-item merges even when this returns false.
  bool hasAnyStandardMergeMoves({bool ignoreEnergy = false}) => _hasAnyMergeMovesInternal(minNeeded: 3, ignoreEnergy: ignoreEnergy);

  bool _hasAnyMergeMovesInternal({required int minNeeded, required bool ignoreEnergy}) {
    try {
      // For UI we sometimes need to know if the *board* has moves even when
      // the player has no energy.
      if (!ignoreEnergy && _playerStats.energy <= 0) return false;
      if (minNeeded < 2) return false;

      final onBoard = _gridItems.where((gi) => gi.gridX != null && gi.gridY != null).toList();
      if (onBoard.isEmpty) return false;

      bool isEligible(GameItem gi, int baseTier) => gi.isWildcard || gi.tier == baseTier;
      bool areAdjacent8(GameItem a, GameItem b) {
        final ax = a.gridX, ay = a.gridY, bx = b.gridX, by = b.gridY;
        if (ax == null || ay == null || bx == null || by == null) return false;
        final dx = (ax - bx).abs();
        final dy = (ay - by).abs();
        return (dx <= 1 && dy <= 1) && !(dx == 0 && dy == 0);
      }

      for (final anchor in onBoard) {
        if (anchor.isWildcard) continue; // avoid ambiguous wildcard-only clusters
        final baseTier = anchor.tier;

        final visited = <String>{anchor.id};
        final queue = <GameItem>[anchor];
        int count = 0;

        while (queue.isNotEmpty) {
          final cur = queue.removeAt(0);
          count++;
          if (count >= minNeeded) return true;
          for (final other in onBoard) {
            if (visited.contains(other.id)) continue;
            if (!isEligible(other, baseTier)) continue;
            if (!areAdjacent8(cur, other)) continue;
            visited.add(other.id);
            queue.add(other);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to compute merge-moves check (minNeeded=$minNeeded): $e');
    }
    return false;
  }

  Future<GameItem?> mergeItems(
    List<GameItem> items, {
    String? preferredTargetItemId,
  }) async {
    if (!canMerge(items)) return null;

    // Merge selection must refer to concrete grid positions.
    if (items.any((e) => e.gridX == null || e.gridY == null)) {
      debugPrint('Merge blocked: some selected items are not on the board.');
      return null;
    }

    // Spend energy for a merge
    if (!_spendEnergyIfPossible(1)) {
      debugPrint('Merge blocked: not enough energy');
      return null;
    }

    // Use the tier of non-wildcards as the base
    final nonWild = items.where((i) => !i.isWildcard).toList();
    final tier = nonWild.first.tier;

    // Determine tier increment based on selection size (wildcards count toward size)
    int increment;
    if (items.length == 2) {
      increment = 1;
    } else {
      final extra = (items.length - 3).clamp(0, 9999);
      increment = 1 + (extra ~/ 2);
    }

    final newTier = tier + increment;
    if (newTier > _itemTemplates.length) return null;

    // IMPORTANT: The merge result must be placed into a cell that becomes empty
    // after removing the selected items. Placing it into the geometric center
    // can target a non-selected cell which might already be occupied.
    //
    // Therefore we compute the visual center for effects/spawns, but choose the
    // actual placement coordinate from the selected items (prefer the user's
    // anchor when provided).
    final centerX = items.map((e) => e.gridX!).reduce((a, b) => a + b) ~/ items.length;
    final centerY = items.map((e) => e.gridY!).reduce((a, b) => a + b) ~/ items.length;

    GameItem? preferred;
    if (preferredTargetItemId != null) {
      for (final e in items) {
        if (e.id == preferredTargetItemId) {
          preferred = e;
          break;
        }
      }
    }
    preferred ??= items.fold<GameItem>(
      items.first,
      (best, cur) {
        final bd = (best.gridX! - centerX).abs() + (best.gridY! - centerY).abs();
        final cd = (cur.gridX! - centerX).abs() + (cur.gridY! - centerY).abs();
        return cd < bd ? cur : best;
      },
    );

    final targetX = preferred.gridX!;
    final targetY = preferred.gridY!;

    for (final item in items) {
      _gridItems.removeWhere((i) => i.id == item.id);
    }

    // Defensive: if the underlying state ever contains duplicates at the target
    // coordinate (hidden items), make sure the merge result doesn't "stack" and
    // appear to overwrite another visible tile.
    final collisions = _gridItems.where((gi) => gi.gridX == targetX && gi.gridY == targetY).toList();
    if (collisions.isNotEmpty) {
      debugPrint(
        'Sanitizing ${collisions.length} unexpected item(s) at merge target ($targetX,$targetY).',
      );
      final indexById = <String, int>{for (var i = 0; i < _gridItems.length; i++) _gridItems[i].id: i};
      for (final c in collisions) {
        final idx = indexById[c.id];
        if (idx == null) continue;
        _gridItems[idx] = _gridItems[idx].copyWith(gridX: null, gridY: null);
      }
    }

    final newItem = _createItem(newTier, targetX, targetY);
    _gridItems.add(newItem);

    // Permanently record discovery of this tier in the collection
    final discovered = List<String>.from(_playerStats.discoveredItems);
    final discoveredKey = 'tier_$newTier';
    if (!discovered.contains(discoveredKey)) discovered.add(discoveredKey);

    _playerStats = _playerStats.copyWith(
      totalMerges: _playerStats.totalMerges + 1,
      highestTier: newTier > _playerStats.highestTier ? newTier : _playerStats.highestTier,
      discoveredItems: discovered,
      updatedAt: DateTime.now(),
    );

    // Consume a power merge charge if this was a 2-item merge
    if (items.length == 2 && _powerMergeCharges > 0) {
      _powerMergeCharges = (_powerMergeCharges - 1).clamp(0, 9999);
      debugPrint('Consumed a Power Merge charge. Remaining: $_powerMergeCharges');
    }

    // Chance-based burst of fresh low-tiers to keep momentum
    _maybeSpawnLowerTiersAround(centerX, centerY);

    await _saveState();
    notifyListeners();

    // === Platform leaderboards & achievements ===
    try {
      // Submit scores
      await _platformService?.submitAllScores(
        totalMerges: _playerStats.totalMerges,
        highestTier: _playerStats.highestTier,
        level: currentLevel,
      );
      // First merge achievement
      if (_playerStats.totalMerges == 1) {
        await _platformService?.unlock(GamePlatformIds.achieveFirstMerge);
      }
      // Tier milestones
      if (newTier >= 5) {
        await _platformService?.unlock(GamePlatformIds.achieveTier5);
      }
      if (newTier >= 10) {
        await _platformService?.unlock(GamePlatformIds.achieveTier10);
      }
      if (newTier >= 15) {
        await _platformService?.unlock(GamePlatformIds.achieveTier15);
      }
      // Level milestones
      final lvl = currentLevel;
      if (lvl >= 5) {
        await _platformService?.unlock(GamePlatformIds.achieveLevel5);
      }
      if (lvl >= 10) {
        await _platformService?.unlock(GamePlatformIds.achieveLevel10);
      }
    } catch (e) {
      debugPrint('Platform updates after merge failed: $e');
    }
    return newItem;
  }

  void moveItem(String itemId, int newX, int newY) {
    final index = _gridItems.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _gridItems[index] = _gridItems[index].copyWith(gridX: newX, gridY: newY);
      _saveState();
      notifyListeners();
    }
  }

  Future<bool> purchaseStarterItem(int tier, int cost) async {
    if (_playerStats.coins < cost) return false;

    final emptySlot = _findEmptyGridSlot();
    if (emptySlot == null) return false;

    final newItem = _createItem(tier, emptySlot['x']!, emptySlot['y']!);
    _gridItems.add(newItem);

    _playerStats = _playerStats.copyWith(
      coins: _playerStats.coins - cost,
      updatedAt: DateTime.now(),
    );

    await _saveState();
    notifyListeners();
    _recordSpawnEvent([newItem]);
    return true;
  }

  Map<String, int>? _findEmptyGridSlot() {
    final occupied = _gridItems.map((item) => '${item.gridX}_${item.gridY}').toSet();
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (!occupied.contains('${x}_$y')) {
          return {'x': x, 'y': y};
        }
      }
    }
    return null;
  }

  Future<void> addGems(int amount) async {
    _playerStats = _playerStats.copyWith(
      gems: _playerStats.gems + amount,
      updatedAt: DateTime.now(),
    );
    await _saveState();
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    _playerStats = _playerStats.copyWith(
      coins: _playerStats.coins + amount,
      updatedAt: DateTime.now(),
    );
    await _saveState();
    notifyListeners();
  }

  // ===================== Abilities & Coins =====================
  bool _spendCoinsIfPossible(int cost) {
    if (_playerStats.coins < cost) {
      debugPrint('Not enough coins. Needed: $cost, have: ${_playerStats.coins}');
      return false;
    }
    _playerStats = _playerStats.copyWith(coins: _playerStats.coins - cost, updatedAt: DateTime.now());
    return true;
  }

  bool _spendGemsIfPossible(int cost) {
    if (_playerStats.gems < cost) {
      debugPrint('Not enough gems. Needed: $cost, have: ${_playerStats.gems}');
      return false;
    }
    _playerStats = _playerStats.copyWith(gems: _playerStats.gems - cost, updatedAt: DateTime.now());
    return true;
  }

  bool _spendEnergyIfPossible(int cost) {
    if (_playerStats.energy < cost) return false;
    // Important: reset the energy regen anchor when spending energy.
    // Otherwise, if the player's [lastEnergyUpdate] is stale (because they
    // haven't *regenerated* recently), re-opening the app can immediately grant
    // “catch-up” energy even if the energy was just spent moments ago.
    final now = DateTime.now();
    _playerStats = _playerStats.copyWith(
      energy: _playerStats.energy - cost,
      lastEnergyUpdate: now,
      updatedAt: now,
    );
    return true;
  }

  Future<bool> abilityShuffleBoard({required int cost}) async {
    if (!_spendCoinsIfPossible(cost)) return false;
    try {
      // Build all grid positions and shuffle them
      final positions = <Map<String, int>>[];
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          positions.add({'x': x, 'y': y});
        }
      }
      positions.shuffle(_rand);
      final maxCells = positions.length; // gridSize * gridSize

      // Only consider items currently on the board (with grid positions).
      // IMPORTANT: the UI renders only the *first* item found per cell
      // (`where(...).firstOrNull`). If stale/duplicate items share the same
      // coordinate, shuffling *all* of them would appear as if Shuffle “added”
      // items by spreading those hidden duplicates into empty cells.
      //
      // So we shuffle only the same set of items that are effectively visible
      // on the grid (first item per cell) and sanitize any duplicates.
      final visibleByCell = <String, GameItem>{};
      final duplicateIds = <String>{};
      for (final gi in _gridItems) {
        final x = gi.gridX;
        final y = gi.gridY;
        if (x == null || y == null) continue;
        final key = '$x,$y';
        if (visibleByCell.containsKey(key)) {
          duplicateIds.add(gi.id);
        } else {
          visibleByCell[key] = gi;
        }
      }

      final onBoard = visibleByCell.values.toList();
      if (onBoard.isEmpty) {
        debugPrint('Shuffle skipped: no on-board items to shuffle.');
        // Refund coins since no action performed
        _playerStats = _playerStats.copyWith(coins: _playerStats.coins + cost, updatedAt: DateTime.now());
        await _savePlayerStats();
        return false;
      }

      // Clear positions so we can reassign cleanly.
      // Also sanitize any duplicates so they can't accidentally become visible.
      final indexById = <String, int>{for (var i = 0; i < _gridItems.length; i++) _gridItems[i].id: i};
      for (final item in onBoard) {
        final idx = indexById[item.id]!;
        _gridItems[idx] = _gridItems[idx].copyWith(gridX: null, gridY: null);
      }
      for (final dupId in duplicateIds) {
        final idx = indexById[dupId];
        if (idx == null) continue;
        _gridItems[idx] = _gridItems[idx].copyWith(gridX: null, gridY: null);
      }

      // Place exactly the same number of items as were visible on-board.
      final placeCount = onBoard.length.clamp(0, maxCells);
      for (int i = 0; i < placeCount; i++) {
        final pos = positions[i];
        final item = onBoard[i];
        final idx = indexById[item.id]!;
        _gridItems[idx] = _gridItems[idx].copyWith(gridX: pos['x'], gridY: pos['y']);
      }

      // Do NOT spawn new items; leave empty cells empty as per spec

      await _saveState();
      notifyListeners();
      debugPrint('Board shuffled using ability. Items moved: $placeCount.');
      return true;
    } catch (e) {
      debugPrint('Shuffle ability failed: $e');
      // Refund coins since shuffle did not complete
      _playerStats = _playerStats.copyWith(coins: _playerStats.coins + cost, updatedAt: DateTime.now());
      await _savePlayerStats();
      return false;
    }
  }

  Future<bool> abilityDuplicateItem(String itemId, {required int cost}) async {
    if (!_spendCoinsIfPossible(cost)) return false;
    try {
      final item = _gridItems.firstWhere((i) => i.id == itemId, orElse: () => throw 'Item not found');
      // Prefer an empty neighbor
      Map<String, int>? emptyNeighbor;
      final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = (item.gridX ?? 0) + dx;
          final ny = (item.gridY ?? 0) + dy;
          if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;
          if (!occupied.contains('${nx}_${ny}')) {
            emptyNeighbor = {'x': nx, 'y': ny};
            break;
          }
        }
        if (emptyNeighbor != null) break;
      }
      emptyNeighbor ??= _findEmptyGridSlot();
      if (emptyNeighbor == null) {
        debugPrint('No empty slot to duplicate item.');
        // Refund coins since no action performed
        _playerStats = _playerStats.copyWith(coins: _playerStats.coins + cost, updatedAt: DateTime.now());
        return false;
      }
      final dup = _createItem(item.tier, emptyNeighbor['x']!, emptyNeighbor['y']!);
      _gridItems.add(dup);
      await _saveState();
      notifyListeners();
      debugPrint('Duplicated item ${item.id} at ${emptyNeighbor['x']},${emptyNeighbor['y']}');
      if (item.gridX != null && item.gridY != null) {
        _recordSpawnEvent([dup], originX: item.gridX, originY: item.gridY);
      } else {
        _recordSpawnEvent([dup]);
      }
      return true;
    } catch (e) {
      debugPrint('Duplicate ability failed: $e');
      return false;
    }
  }

  Future<bool> abilityClearItem(String itemId, {required int cost}) async {
    if (!_spendCoinsIfPossible(cost)) return false;
    try {
      final before = _gridItems.length;
      _gridItems.removeWhere((i) => i.id == itemId);
      if (_gridItems.length == before) {
        // Nothing removed; refund
        _playerStats = _playerStats.copyWith(coins: _playerStats.coins + cost, updatedAt: DateTime.now());
        debugPrint('Clear ability: item not found, refunding coins.');
        return false;
      }
      await _saveState();
      notifyListeners();
      debugPrint('Cleared item $itemId');
      return true;
    } catch (e) {
      debugPrint('Clear ability failed: $e');
      return false;
    }
  }

  // Gem-consumable: clear a 3x3 area centered on the selected item
  Future<bool> abilityBombArea(String centerItemId) async {
    if (_playerStats.bombRunes <= 0) {
      debugPrint('No Bomb Runes available.');
      return false;
    }
    try {
      final center = _gridItems.firstWhere((i) => i.id == centerItemId, orElse: () => throw 'Item not found');
      if (center.gridX == null || center.gridY == null) return false;
      final cx = center.gridX!;
      final cy = center.gridY!;
      final before = _gridItems.length;
      _gridItems.removeWhere((i) {
        if (i.gridX == null || i.gridY == null) return false;
        final dx = (i.gridX! - cx).abs();
        final dy = (i.gridY! - cy).abs();
        return dx <= 1 && dy <= 1; // 3x3 area including center
      });
      if (_gridItems.length == before) {
        debugPrint('Bomb Rune used but nothing to remove.');
      }
      _playerStats = _playerStats.copyWith(bombRunes: (_playerStats.bombRunes - 1).clamp(0, 9999), updatedAt: DateTime.now());
      await _saveState();
      notifyListeners();
      debugPrint('Bomb Rune exploded at $cx,$cy');
      return true;
    } catch (e) {
      debugPrint('Bomb ability failed: $e');
      return false;
    }
  }

  // Gem-consumable: upgrade a selected item by +1 tier
  Future<bool> abilityTierUp(String itemId) async {
    if (_playerStats.tierUpTokens <= 0) {
      debugPrint('No Tier Up tokens available.');
      return false;
    }
    try {
      final idx = _gridItems.indexWhere((i) => i.id == itemId);
      if (idx < 0) return false;
      final item = _gridItems[idx];
      if (item.isWildcard) return false;
      if (item.tier >= _itemTemplates.length) return false;
      final newTier = item.tier + 1;
      final template = _itemTemplates[newTier]!;
      _gridItems[idx] = item.copyWith(
        tier: newTier,
        name: template['name'],
        emoji: template['emoji'],
        description: template['description'],
      );
      _playerStats = _playerStats.copyWith(tierUpTokens: (_playerStats.tierUpTokens - 1).clamp(0, 9999), updatedAt: DateTime.now());
      await _saveState();
      notifyListeners();
      debugPrint('Tier Up applied to ${item.id} -> tier $newTier');
      return true;
    } catch (e) {
      debugPrint('Tier Up ability failed: $e');
      return false;
    }
  }

  Future<bool> abilitySummonBurst({required int count, required int cost}) async {
    // Guard: if the board is full, do not allow summoning
    final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
    int emptySlots = 0;
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (!occupied.contains('${x}_$y')) emptySlots++;
      }
    }
    if (emptySlots == 0) {
      debugPrint('Summon blocked: board is full (no empty slots).');
      return false;
    }

    if (!_spendCoinsIfPossible(cost)) return false;
    try {
    final created = _fillMatchingLowest(count: count);
      await _saveState();
      notifyListeners();
      debugPrint('Summoned $count low-tier items.');
      _recordSpawnEvent(created);
      return true;
    } catch (e) {
      debugPrint('Summon ability failed: $e');
      return false;
    }
  }

  /// Summons a burst of low-tier items, paid with gems.
  ///
  /// Used by the “No moves left” offer, where we want to upsell gem packs when
  /// the player can’t afford the summon.
  Future<bool> abilitySummonBurstWithGems({required int count, required int gemCost}) async {
    // Guard: if the board is full, do not allow summoning
    final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
    int emptySlots = 0;
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (!occupied.contains('${x}_$y')) emptySlots++;
      }
    }
    if (emptySlots == 0) {
      debugPrint('Summon blocked: board is full (no empty slots).');
      return false;
    }

    if (!_spendGemsIfPossible(gemCost)) return false;
    try {
      final created = _fillMatchingLowest(count: count);
      await _saveState();
      notifyListeners();
      debugPrint('Summoned $count low-tier items (paid with gems).');
      _recordSpawnEvent(created);
      return true;
    } catch (e) {
      debugPrint('Summon (gems) ability failed: $e');
      return false;
    }
  }

  Future<bool> abilityBuyPowerMerge({int charges = 1, required int cost}) async {
    if (!_spendCoinsIfPossible(cost)) return false;
    _powerMergeCharges += charges;
    notifyListeners();
    debugPrint('Purchased Power Merge charges: +$charges. Total: $_powerMergeCharges');
    await _saveState();
    return true;
  }

  Future<void> addEnergy(int amount) async {
    _playerStats = _playerStats.copyWith(
      energy: (_playerStats.energy + amount).clamp(0, _playerStats.maxEnergy),
      updatedAt: DateTime.now(),
    );
    await _saveState();
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    _playerStats = _playerStats.copyWith(
      hasCompletedTutorial: true,
      updatedAt: DateTime.now(),
    );
    await _saveState();
    notifyListeners();
  }

  Future<void> _saveState() async {
    try {
      await _savePlayerStats().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      debugPrint('Save player stats timed out (saveState)');
    } catch (e) {
      debugPrint('Save player stats failed (saveState): $e');
    }
    try {
      await _saveGridItems().timeout(const Duration(seconds: 6));
    } on TimeoutException {
      debugPrint('Save grid items timed out (saveState)');
    } catch (e) {
      debugPrint('Save grid items failed (saveState): $e');
    }
  }
  
  Future<void> _savePlayerStats() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    
    try {
      final userId = _userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Skip saving player stats: userId is null/empty');
        return;
      }
      final data = _playerStats.copyWith(userId: userId).toJson();
      await _firebaseService!.firestore
          .collection('player_stats')
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save player stats: $e');
    }
  }
  
  Future<void> _saveGridItems() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    
    try {
      final userId = _userId;
      if (userId == null || userId.isEmpty) {
        debugPrint('Skip saving grid items: userId is null/empty');
        return;
      }
      final batch = _firebaseService!.firestore.batch();
      final subCol = _firebaseService!.firestore
          .collection('player_stats')
          .doc(userId)
          .collection('grid_items');
      
      // Delete all existing items for this user (in subcollection)
      final existingItems = await subCol.get();
      for (final doc in existingItems.docs) {
        batch.delete(doc.reference);
      }
      
      // Add current items
      for (final item in _gridItems) {
        final docRef = subCol.doc(item.id);
        batch.set(docRef, item.copyWith(userId: userId).toJson());
      }
      
      await batch.commit();
      debugPrint('Saved ${_gridItems.length} grid items to subcollection for user $userId');
    } on FirebaseException catch (e) {
      debugPrint('Failed to save grid items (subcollection) [${e.code}]: ${e.message}');
      // Legacy fallback: attempt top-level write if rules still allow it
      try {
        final userId = _userId;
        if (userId == null || userId.isEmpty) {
          debugPrint('Skip legacy grid item save: userId is null/empty');
          return;
        }
        final batch = _firebaseService!.firestore.batch();
        final legacyQuery = await _firebaseService!.firestore
            .collection('grid_items')
            .where('user_id', isEqualTo: userId)
            .get();
        for (final doc in legacyQuery.docs) {
          batch.delete(doc.reference);
        }
        for (final item in _gridItems) {
          final docRef = _firebaseService!.firestore
              .collection('grid_items')
              .doc(item.id);
          batch.set(docRef, item.copyWith(userId: userId).toJson());
        }
        await batch.commit();
        debugPrint('Saved ${_gridItems.length} grid items to legacy top-level collection for user $userId');
      } catch (e2) {
        debugPrint('Failed to save grid items (legacy fallback): $e2');
      }
    } catch (e) {
      debugPrint('Failed to save grid items: $e');
    }
  }

  List<GameItem> getItemsInRange(int x, int y, int range) {
    return _gridItems.where((item) {
      final gx = item.gridX;
      final gy = item.gridY;
      if (gx == null || gy == null) return false;
      final dx = (gx - x).abs();
      final dy = (gy - y).abs();
      return dx <= range && dy <= range && !(dx == 0 && dy == 0);
    }).toList();
  }

  List<GameItem> getAllDiscoveredItems() {
    final discoveredMap = <int, GameItem>{};
    final discoveredTiers = _discoveredTiers;
    for (int tier = 1; tier <= _itemTemplates.length; tier++) {
      final template = _itemTemplates[tier]!;
      final isDiscovered = discoveredTiers.contains(tier) || tier <= 3;
      discoveredMap[tier] = GameItem(
        id: 'template_$tier',
        name: template['name'],
        tier: tier,
        emoji: template['emoji'],
        description: template['description'],
        isDiscovered: isDiscovered,
      );
    }
    return discoveredMap.values.toList();
  }

  // ===================== Specials & Ads =====================
  Future<bool> purchaseSpecial(String id, int gemCost) async {
    if (!_spendGemsIfPossible(gemCost)) return false;
    switch (id) {
      case 'special_wildcard_orb':
        _playerStats = _playerStats.copyWith(wildcardOrbs: _playerStats.wildcardOrbs + 1, updatedAt: DateTime.now());
        await _savePlayerStats();
        notifyListeners();
        return true;
      case 'special_energy_booster':
        final newMax = _playerStats.maxEnergy + 50;
        final newEnergy = (_playerStats.energy + 50).clamp(0, newMax);
        _playerStats = _playerStats.copyWith(maxEnergy: newMax, energy: newEnergy, updatedAt: DateTime.now());
        await _savePlayerStats();
        notifyListeners();
        return true;
      case 'special_power_merge_pack':
        _powerMergeCharges += 3;
        await _savePlayerStats();
        notifyListeners();
        return true;
      case 'special_bomb_rune':
        _playerStats = _playerStats.copyWith(bombRunes: _playerStats.bombRunes + 1, updatedAt: DateTime.now());
        await _savePlayerStats();
        notifyListeners();
        return true;
      case 'special_tier_up':
        _playerStats = _playerStats.copyWith(tierUpTokens: _playerStats.tierUpTokens + 1, updatedAt: DateTime.now());
        await _savePlayerStats();
        notifyListeners();
        return true;
      case 'special_time_warp':
        // Instant +100 energy
        await addEnergy(100);
        return true;
      case 'special_auto_select_upgrade':
        final current = _playerStats.autoSelectCount;
        if (current >= 10) {
          // Refund, already at cap
          _playerStats = _playerStats.copyWith(gems: _playerStats.gems + gemCost, updatedAt: DateTime.now());
          return false;
        }
        _playerStats = _playerStats.copyWith(autoSelectCount: (current == 0 ? 3 : (current + 1).clamp(3, 10)), updatedAt: DateTime.now());
        await _savePlayerStats();
        notifyListeners();
        return true;
      default:
        // Unknown special -> refund
        _playerStats = _playerStats.copyWith(gems: _playerStats.gems + gemCost, updatedAt: DateTime.now());
        return false;
    }
  }

  // ===================== Spins =====================
  // Spend gems for an extra daily spin. No side effects other than currency change.
  Future<bool> purchaseExtraDailySpin({int gemCost = 30}) async {
    if (!_spendGemsIfPossible(gemCost)) return false;
    await _savePlayerStats();
    notifyListeners();
    return true;
  }

  Future<void> markAdsRemoved() async {
    _playerStats = _playerStats.copyWith(adRemovalPurchased: true, updatedAt: DateTime.now());
    await _savePlayerStats();
    notifyListeners();
  }

  Future<bool> abilityPlaceWildcard({String? nearItemId}) async {
    if (_playerStats.wildcardOrbs <= 0) {
      debugPrint('No wildcard orbs available.');
      return false;
    }
    final target = _findPlacementNear(nearItemId: nearItemId);
    if (target == null) {
      debugPrint('No space to place a wildcard.');
      return false;
    }
    final wildcard = GameItem(
      id: _makeId(0),
      name: 'Wildcard',
      tier: 1, // visual only, not used for equality
      emoji: '🃏',
      description: 'Merges with anything',
      gridX: target['x'],
      gridY: target['y'],
      isDiscovered: true,
      isWildcard: true,
    );
    _gridItems.add(wildcard);
    _playerStats = _playerStats.copyWith(wildcardOrbs: (_playerStats.wildcardOrbs - 1).clamp(0, 9999), updatedAt: DateTime.now());
    await _saveState();
    notifyListeners();
    _recordSpawnEvent([wildcard]);
    return true;
  }

  // Explicit placement at a specific empty cell
  Future<bool> abilityPlaceWildcardAt(int x, int y) async {
    if (_playerStats.wildcardOrbs <= 0) {
      debugPrint('No wildcard orbs available.');
      return false;
    }
    // Ensure within bounds and empty
    if (x < 0 || y < 0 || x >= gridSize || y >= gridSize) return false;
    final occupied = _gridItems.any((i) => i.gridX == x && i.gridY == y);
    if (occupied) {
      debugPrint('Target cell ($x,$y) is occupied.');
      return false;
    }
    final wildcard = GameItem(
      id: _makeId(0),
      name: 'Wildcard',
      tier: 1,
      emoji: '🃏',
      description: 'Merges with anything',
      gridX: x,
      gridY: y,
      isDiscovered: true,
      isWildcard: true,
    );
    _gridItems.add(wildcard);
    _playerStats = _playerStats.copyWith(wildcardOrbs: (_playerStats.wildcardOrbs - 1).clamp(0, 9999), updatedAt: DateTime.now());
    await _saveState();
    notifyListeners();
    _recordSpawnEvent([wildcard]);
    return true;
  }

  Map<String, int>? _findPlacementNear({String? nearItemId}) {
    if (nearItemId != null) {
      final anchor = _gridItems.firstWhere((i) => i.id == nearItemId, orElse: () => _gridItems.isNotEmpty ? _gridItems.first : GameItem(id: 'none', name: 'x', tier: 1, emoji: 'x', description: 'x'));
      if (anchor.gridX != null && anchor.gridY != null) {
        final occupied = _gridItems.map((i) => '${i.gridX}_${i.gridY}').toSet();
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = (anchor.gridX ?? 0) + dx;
            final ny = (anchor.gridY ?? 0) + dy;
            if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;
            if (!occupied.contains('${nx}_${ny}')) return {'x': nx, 'y': ny};
          }
        }
      }
    }
    return _findEmptyGridSlot();
  }
}

// Lightweight spawn event description for UI animations
class SpawnEvent {
  final List<GameItem> items;
  final int originX;
  final int originY;
  const SpawnEvent({required this.items, required this.originX, required this.originY});
}
