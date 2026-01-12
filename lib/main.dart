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
import 'package:mergeworks/services/game_platform_service.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'nav.dart';
import 'package:mergeworks/services/log_service.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mergeworks/services/accessibility_service.dart';
import 'package:mergeworks/widgets/captions_overlay.dart';

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
        ChangeNotifierProvider(create: (_) => GamePlatformService()..initialize()),
        ChangeNotifierProxyProvider2<FirebaseService, GamePlatformService, GameService>(
          create: (_) => GameService(),
          update: (_, firebaseService, platformService, gameService) {
            gameService!.setFirebaseService(firebaseService);
            gameService.setPlatformService(platformService);
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
        ChangeNotifierProvider(create: (_) => AccessibilityService()..initialize()),
        Provider(create: (_) => HapticsService()),
        Provider.value(value: AdsService.instance),
      ],
      child: Consumer<AccessibilityService>(
        builder: (context, a11y, _) {
          final ThemeMode mode = a11y.forceDark ? ThemeMode.dark : ThemeMode.system;
          final effectiveLight = a11y.highContrast ? highContrastLightTheme() : lightTheme;
          final effectiveDark = a11y.highContrast ? highContrastDarkTheme() : darkTheme;
          return MaterialApp.router(
            title: 'MergeWorks',
            debugShowCheckedModeBanner: false,
            theme: effectiveLight,
            darkTheme: effectiveDark,
            themeMode: mode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            localeResolutionCallback: (deviceLocale, supported) {
              // Default to device locale if supported; otherwise fall back to English.
              if (deviceLocale == null) return const Locale('en');
              for (final l in supported) {
                if (l.languageCode == deviceLocale.languageCode) return l;
              }
              return const Locale('en');
            },
            routerConfig: AppRouter.router,
            builder: (context, child) {
              // Text scale and captions overlay
              final mq = MediaQuery.of(context);
              final scaled = mq.copyWith(textScaler: TextScaler.linear(a11y.textScale));
              return MediaQuery(
                data: scaled,
                child: Stack(
                  children: [
                    if (child != null) child,
                    const CaptionsOverlay(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
