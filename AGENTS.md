# MergeWorks — Agent Guide

This document briefs AI agents on how to work effectively in this Flutter codebase.

## 1) Project overview
MergeWorks is a casual merge puzzle game built with Flutter (Material 3), using Firebase (Auth, Firestore, Functions) for persistence and platform features. State is organized into service classes (ChangeNotifiers) injected with Provider. Navigation uses go_router. The game runs on Android, iOS, and Web (Dreamflow preview runs on Web).

Key screens:
- GameBoardScreen (home) — main 6×6 board, selection, abilities, merge flow
- ShopScreen — IAP and gem-based specials
- CollectionScreen — discovered items book
- AchievementsScreen — achievements and daily quests
- DailySpinScreen — daily rewards
- SettingsScreen — audio + accessibility options

## 2) Architecture & conventions
- State management: Provider with ChangeNotifier (+ ProxyProvider for dependent services). Services expose small, explicit APIs; UI reads via context.watch/read.
- Navigation: go_router configured in lib/nav.dart with AppRoutes constants. Always navigate via context.go(), context.push(), context.pop(). Do not use Navigator.
- Data models: Plain classes with toJson/fromJson. Firestore timestamps mapped via Timestamp; IDs are strings.
- Persistence: 
  - Firestore user document in player_stats/{userId} and user-scoped subcollection player_stats/{userId}/grid_items for grid state. Legacy fallback to top-level grid_items exists.
  - Local device prefs (SharedPreferences) for UI/audio/accessibility toggles.
- Theming: Centralized in lib/theme.dart using ColorScheme and GoogleFonts Inter. High-contrast variants provided. AppSpacing/AppRadius and TextStyle extensions promote consistency.
- Audio/Haptics: Audio via audioplayers with background loop and SFX; Haptics via HapticFeedback helpers. Web requires a user gesture to start music.
- Ads: AdMob service is Android-only (no-op elsewhere). Ad unit IDs can be provided via compile-time environment variables.
- IAP: in_app_purchase for native platforms; simulated purchases on Web.
- Logging/diagnostics: LogService captures print/debugPrint/FlutterError into a ring buffer. Prefer debugPrint for errors; don’t swallow exceptions.

## 3) Important directories
- lib/main.dart — app bootstrap (Firebase init, MultiProvider, MaterialApp.router)
- lib/nav.dart — go_router routes and paths
- lib/theme.dart — ColorScheme, text styles, spacing, high-contrast themes
- lib/models/ — GameItem, PlayerStats, etc.
- lib/services/ — Core logic per domain (GameService, FirebaseService, ShopService, AudioService, Quest/Achievement, Ads, Haptics, Accessibility, Log)
- lib/screens/ — Feature screens (board, shop, settings, etc.)
- lib/widgets/ — Reusable UI components (grid item, overlays, energy bar, etc.)
- lib/firebase_options.dart — Firebase config (generated)
- functions/ — Firebase Cloud Functions (region us-central1)
- assets/ — Audio and images referenced by the app

## 4) Code style & naming
- Imports: Always use absolute imports (package:mergeworks/...).
- Naming: Files in snake_case, classes in UpperCamelCase, fields/methods in lowerCamelCase.
- Material 3: Use ThemeData and the Data-suffixed theme classes (e.g., CardThemeData). Avoid deprecated APIs.
- Colors: Never hard-code outside theme.dart. Use Color.withValues(alpha: x) rather than withOpacity(). Set icon/text colors explicitly in buttons.
- Widgets: Prefer small public widget classes over builder functions. Keep DRY; extract reusable components into lib/widgets.
- Logging: Use debugPrint for errors and context. Avoid print except via LogService hooks.
- Accessibility: Respect AccessibilityService (text scale, forceDark, high contrast, differentiate without color). Avoid color-only indicators.

## 5) Common implementation patterns
- Adding a service
  1) Create a ChangeNotifier in lib/services.
  2) Register in MultiProvider (main.dart). If it depends on other services, use ProxyProvider.
  3) Expose a minimal API; log failures with debugPrint. Persist to Firestore as needed.

- Adding a screen
  1) Create a Stateless/StatefulWidget in lib/screens.
  2) Add a GoRoute in nav.dart (AppRoutes constants) and navigate with context.go('/path') or context.push('/path').
  3) Consume services via context.watch/read; never use global singletons unless that service is intentionally a singleton (e.g., AdsService.instance).

- Firestore data rules in this app
  - Player state lives at player_stats/{userId}. Grid items are stored under player_stats/{userId}/grid_items with documents keyed by GameItem.id.
  - GameService batches writes: deletes the subcollection then writes current items, with a legacy fallback to top-level grid_items if necessary.
  - PlayerStats timestamps are stored as Timestamp; see PlayerStats.toJson/fromJson.

- Game board + merge rules (high level)
  - Board is 6×6. Items have tiers; wildcards (🃏) can merge with any tier.
  - Merge requires 3 connected items of same base tier (8-direction adjacency) unless player has Power Merge charges, which allow 2-item merges. Each merge costs 1 energy; energy regenerates over time.
  - Long-press Auto-Select: If player owns the “Auto-Select” upgrade (autoSelectCount > 0), a long-press selects a connected cluster (base tier + wildcards) up to the player’s cap (3→10). If valid, it immediately triggers the normal merge pipeline.
  - After merges, GameService may spawn low-tier items near the merge location and updates achievements/quests and platform scores.

- Audio usage
  - Call AudioService.maybeStartMusicFromUserGesture() on user interactions (tap/long-press) to ensure background music starts on Web.
  - Use AudioService helpers for SFX (playMergeSound, playAbilityUseSound, etc.).

- UI & theme usage
  - Use Theme.of(context).colorScheme and context.textStyles. Spacing via AppSpacing and AppRadius; avoid hard-coded sizes/colors.

## 6) Project-specific rules & constraints
- Navigation: Must use go_router (context.go/push/pop); do not use Navigator.push/pop.
- Theme mode: Default is dark mode; app should not follow system theme. AccessibilityService.forceDark controls ThemeMode.
- Web renderer: Do not alter Flutter web renderer settings (Dreamflow requires CanvasKit default).
- Ads: Only initialize AdMob on Android. iOS/web paths are no-ops to avoid crashes in previews.
- Cloud Functions: Region is us-central1; sample callable function name: ping.
- IAP: Web is simulation-only; on-device uses in_app_purchase. Non-consumable ID for ad removal is nonconsumable.remove_adsAll.
- Firestore structure is authoritative; prefer user-scoped subcollections. Legacy top-level grid_items remains for migration.
- Logging policy: Always capture issues with debugPrint for visibility via LogService.

## 7) Quick references
- Routes (nav.dart):
  - '/': GameBoardScreen
  - '/collection': CollectionScreen
  - '/shop': ShopScreen
  - '/achievements': AchievementsScreen
  - '/settings': SettingsScreen
  - '/daily-spin': DailySpinScreen

- Special shop items (gems):
  - special_auto_select_upgrade — increases autoSelectCount (cap 10)
  - special_wildcard_orb, special_energy_booster (+50 max), special_power_merge_pack (+3), special_bomb_rune, special_tier_up, special_time_warp

- Important APIs to reuse:
  - GameService.canMerge(...), mergeItems(...), ability* methods, addCoins/addGems/addEnergy
  - AudioService.playMergeSound(), maybeStartMusicFromUserGesture()
  - HapticsService.onMerge(...)

Following these patterns keeps new features consistent, testable, and compatible with Dreamflow’s preview/runtime environment.