import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mergeworks/services/game_service.dart';
import 'package:mergeworks/services/achievement_service.dart';
import 'package:mergeworks/services/quest_service.dart';
import 'package:mergeworks/services/shop_service.dart';
import 'package:mergeworks/services/audio_service.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/services/haptics_service.dart';
import 'package:mergeworks/services/ads_service.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'nav.dart';
import 'package:mergeworks/services/log_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Capture console outputs and framework errors into LogService
  await runZonedGuarded(() async {
    LogService.hookGlobalLogging();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization error: $e');
    }
    // Initialize AdMob (Android only; no-op elsewhere)
    await AdsService.instance.initialize();
    runApp(const MyApp());
  }, (error, stack) {
    // Ensure uncaught errors are still logged
    LogService.instance.add('Uncaught error: $error');
    if (stack != null) LogService.instance.add(stack.toString());
  }, zoneSpecification: LogService.zoneSpecForPrintCapture());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LogService.instance),
        ChangeNotifierProvider(create: (_) => FirebaseService()..initialize()),
        ChangeNotifierProxyProvider<FirebaseService, GameService>(
          create: (_) => GameService(),
          update: (_, firebaseService, gameService) {
            gameService!.setFirebaseService(firebaseService);
            return gameService;
          },
        ),
        ChangeNotifierProxyProvider<FirebaseService, AchievementService>(
          create: (_) => AchievementService(),
          update: (_, firebaseService, achievementService) {
            achievementService!.setFirebaseService(firebaseService);
            return achievementService;
          },
        ),
        ChangeNotifierProxyProvider<FirebaseService, QuestService>(
          create: (_) => QuestService(),
          update: (_, firebaseService, questService) {
            questService!.setFirebaseService(firebaseService);
            return questService;
          },
        ),
        ChangeNotifierProvider(create: (_) => ShopService()..initialize()),
        ChangeNotifierProvider(create: (_) => AudioService()..initialize()),
        Provider(create: (_) => HapticsService()),
        Provider.value(value: AdsService.instance),
      ],
      child: MaterialApp.router(
        title: 'MergeWorks',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
