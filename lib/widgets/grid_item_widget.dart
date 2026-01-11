import 'package:flutter/material.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/theme.dart';

class GridItemWidget extends StatefulWidget {
  final GameItem item;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const GridItemWidget({
    super.key,
    required this.item,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  State<GridItemWidget> createState() => _GridItemWidgetState();
}

class _GridItemWidgetState extends State<GridItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _getItemSize(widget.item.tier);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.isHighlighted ? 1.18 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isHighlighted
                  ? [
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                    ]
                  : [
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: widget.isHighlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2,
                  )
                : null,
            boxShadow: widget.isHighlighted
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: widget.isHighlighted ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Text(
                    widget.item.emoji,
                    style: TextStyle(fontSize: size),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'T${widget.item.tier}',
                  style: context.textStyles.labelSmall?.bold.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getItemSize(int tier) {
    if (tier <= 3) return 30;
    if (tier <= 6) return 36;
    if (tier <= 10) return 42;
    if (tier <= 14) return 48;
    return 54;
  }
}
