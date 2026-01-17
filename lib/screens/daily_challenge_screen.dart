import 'package:flutter/material.dart';
import 'package:mergeworks/screens/game_board_screen.dart';

/// Wrapper screen that runs the main board UI in Daily Challenge mode.
class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) => const GameBoardScreen(isDailyChallenge: true);
}
