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
import 'firebase_options.dart';
import 'theme.dart';
import 'nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
        ChangeNotifierProvider(create: (_) => ShopService()),
        ChangeNotifierProvider(create: (_) => AudioService()..initialize()),
        Provider(create: (_) => HapticsService()),
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
