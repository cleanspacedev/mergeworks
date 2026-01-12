import 'package:flutter/material.dart';
import 'package:mergeworks/theme.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialOverlay({super.key, required this.onComplete});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _step = 0;

  final List<Map<String, String>> _steps = [
    {
      'title': 'Welcome to MergeWorks! ✨',
      'description': 'Combine identical items to create more powerful magical objects!',
    },
    {
      'title': 'Drag to Merge 🎯',
      'description': 'Drag 3 or more matching items together. Bigger groups create even higher tiers!',
    },
    {
      'title': 'Watch Your Energy ⚡',
      'description': 'Each action costs energy. It refills over time (1 energy per 5 minutes).',
    },
    {
      'title': 'Collect Them All 💎',
      'description': 'Discover all 18 magical items and reach legendary status!',
    },
  ];

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_step];
    
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Card(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentStep['title']!,
                    style: context.textStyles.headlineSmall?.bold.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    currentStep['description']!,
                    style: context.textStyles.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _step
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _nextStep,
                      child: Text(_step < _steps.length - 1 ? 'Next' : 'Start Playing!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
