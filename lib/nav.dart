import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mergeworks/screens/game_board_screen.dart';
import 'package:mergeworks/screens/collection_screen.dart';
import 'package:mergeworks/screens/shop_screen.dart';
import 'package:mergeworks/screens/achievements_screen.dart';
import 'package:mergeworks/screens/settings_screen.dart';
import 'package:mergeworks/screens/daily_spin_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const GameBoardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.collection,
        name: 'collection',
        pageBuilder: (context, state) => const MaterialPage(
          child: CollectionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.shop,
        name: 'shop',
        pageBuilder: (context, state) => const MaterialPage(
          child: ShopScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        name: 'achievements',
        pageBuilder: (context, state) => const MaterialPage(
          child: AchievementsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => const MaterialPage(
          child: SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dailySpin,
        name: 'daily-spin',
        pageBuilder: (context, state) => const MaterialPage(
          child: DailySpinScreen(),
        ),
      ),
    ],
  );
}

class AppRoutes {
  static const String home = '/';
  static const String collection = '/collection';
  static const String shop = '/shop';
  static const String achievements = '/achievements';
  static const String settings = '/settings';
  static const String dailySpin = '/daily-spin';
}
