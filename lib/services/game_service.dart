import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/models/player_stats.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'dart:math';

class GameService extends ChangeNotifier {
  FirebaseService? _firebaseService;
  // Unique ID generator sequence to avoid duplicate IDs when creating items rapidly
  int _idSeq = 0;
  String _makeId(int tier) => 'gi_${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}_t$tier';
  final Random _rand = Random();
  
  // Ephemeral ability state (not persisted)
  int _powerMergeCharges = 0;
  
  PlayerStats _playerStats = PlayerStats();
  List<GameItem> _gridItems = [];
  bool _isLoading = false;

  PlayerStats get playerStats => _playerStats;
  List<GameItem> get gridItems => _gridItems;
  bool get isLoading => _isLoading;
  int get powerMergeCharges => _powerMergeCharges;

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
    _firebaseService!.addListener(_onAuthStateChanged);
    if (_firebaseService!.isInitialized && _firebaseService!.isAuthenticated) {
      initialize();
    }
  }
  
  void _onAuthStateChanged() {
    if (_firebaseService!.isAuthenticated && !_isLoading) {
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
  static int _levelForTier(int count) {
    // Fast early, slower later: reach new levels quickly at first, then
    // per-level requirements increase by +1 each level (triangular growth).
    // Examples (cumulative discovered unique tiers -> level):
    // 1 -> L1, 3 -> L2, 6 -> L3, 10 -> L4, 15 -> L5, 21 -> L6, ...
    if (count <= 1) return 1;
    int level = 1;
    int cumulative = 1; // tiers required to be at current level
    int increment = 2;  // tiers needed to reach the next level initially
    while (count > cumulative) {
      cumulative += increment;
      level++;
      // Make it progressively slower: increase requirement a little every level
      increment += 1;
      if (level > 999) break; // safety guard
    }
    return level;
  }
  // Link levels to collection progress: your level is determined by how many unique tiers
  // you have discovered in the collection book (not just the highest on-board tier)
  int get currentLevel {
    final count = discoveredTierCount <= 0 ? 1 : discoveredTierCount;
    return _levelForTier(count);
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
    
    _isLoading = true;
    notifyListeners();

    try {
      final userId = _firebaseService!.userId!;
      
      // Load player stats from Firestore
      final statsDoc = await _firebaseService!.firestore
          .collection('player_stats')
          .doc(userId)
          .get();
      
      if (statsDoc.exists) {
        _playerStats = PlayerStats.fromJson(statsDoc.data()!);
      } else {
        // Create new player stats
        _playerStats = PlayerStats(userId: userId);
        await _savePlayerStats();
      }

      // Load grid items from Firestore
      final itemsQuery = await _firebaseService!.firestore
          .collection('grid_items')
          .where('user_id', isEqualTo: userId)
          .get();
      
      _gridItems = itemsQuery.docs
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
        await _saveState();
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
        await _savePlayerStats();
      }

      // Ensure the board feels lively: keep a minimum population that scales with level
      _ensureTargetPopulation();

      _updateEnergy();
      await _checkDailyLogin();
    } catch (e) {
      debugPrint('Failed to initialize game: $e');
      _initializeStarterItems();
      _ensureTargetPopulation();
    } finally {
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
    _fillRandomLowTiers(count: 12, maxTier: 2);
    _saveState();
  }

  // Target population scales by current level to keep screens feeling rich
  void _ensureTargetPopulation() {
    final lvl = currentLevel;
    final target = 18 + (lvl - 1) * 4; // +4 items per level
    final minCount = target.clamp(18, 32); // cap to avoid overcrowding a 6x6 grid
    final deficit = minCount - _gridItems.length;
    if (deficit > 0) {
      _fillRandomLowTiers(count: deficit, maxTier: 2);
      _saveState();
    }
  }

  List<GameItem> _fillRandomLowTiers({required int count, int maxTier = 2}) {
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
    for (final slot in allSlots) {
      if (added >= count) break;
      final tier = (_rand.nextDouble() < 0.8) ? 1 : min(2, maxTier); // bias toward tier-1
      final item = _createItem(tier, slot['x']!, slot['y']!);
      _gridItems.add(item);
      created.add(item);
      added++;
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
        final tier = _rand.nextDouble() < 0.85 ? 1 : 2;
        final it = _createItem(tier, slot['x']!, slot['y']!);
        _gridItems.add(it);
        spawned.add(it);
        placed++;
      }

      if (placed < toAdd) {
        // Fallback: fill anywhere
        final extra = _fillRandomLowTiers(count: toAdd - placed, maxTier: 2);
        spawned.addAll(extra);
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

  Future<GameItem?> mergeItems(List<GameItem> items) async {
    if (!canMerge(items)) return null;

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

    final centerX = items.map((e) => e.gridX!).reduce((a, b) => a + b) ~/ items.length;
    final centerY = items.map((e) => e.gridY!).reduce((a, b) => a + b) ~/ items.length;

    for (final item in items) {
      _gridItems.removeWhere((i) => i.id == item.id);
    }

    final newItem = _createItem(newTier, centerX, centerY);
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
    _playerStats = _playerStats.copyWith(energy: _playerStats.energy - cost, updatedAt: DateTime.now());
    return true;
  }

  Future<bool> abilityShuffleBoard({required int cost}) async {
    if (!_spendCoinsIfPossible(cost)) return false;
    try {
      final positions = <Map<String, int>>[];
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          positions.add({'x': x, 'y': y});
        }
      }
      positions.shuffle(_rand);
      // Assign as many positions as items we have
      for (int i = 0; i < _gridItems.length; i++) {
        final pos = positions[i];
        _gridItems[i] = _gridItems[i].copyWith(gridX: pos['x'], gridY: pos['y']);
      }
      await _saveState();
      notifyListeners();
      debugPrint('Board shuffled using ability.');
      return true;
    } catch (e) {
      debugPrint('Shuffle ability failed: $e');
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
      final created = _fillRandomLowTiers(count: count, maxTier: 2);
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
    await _savePlayerStats();
    await _saveGridItems();
  }
  
  Future<void> _savePlayerStats() async {
    if (_firebaseService == null || !_firebaseService!.isAuthenticated) return;
    
    try {
      final userId = _firebaseService!.userId!;
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
      final userId = _firebaseService!.userId!;
      final batch = _firebaseService!.firestore.batch();
      
      // Delete all existing items for this user
      final existingItems = await _firebaseService!.firestore
          .collection('grid_items')
          .where('user_id', isEqualTo: userId)
          .get();
      
      for (final doc in existingItems.docs) {
        batch.delete(doc.reference);
      }
      
      // Add current items
      for (final item in _gridItems) {
        final docRef = _firebaseService!.firestore
            .collection('grid_items')
            .doc(item.id);
        batch.set(docRef, item.copyWith(userId: userId).toJson());
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to save grid items: $e');
    }
  }

  List<GameItem> getItemsInRange(int x, int y, int range) {
    return _gridItems.where((item) {
      final dx = (item.gridX! - x).abs();
      final dy = (item.gridY! - y).abs();
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
