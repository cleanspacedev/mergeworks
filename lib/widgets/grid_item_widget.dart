import 'package:flutter/material.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/widgets/unique_item_glyph.dart';
import 'package:provider/provider.dart';
import 'package:mergeworks/services/accessibility_service.dart';

class GridItemWidget extends StatefulWidget {
  final GameItem item;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GridItemWidget({
    super.key,
    required this.item,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
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
    final a11y = context.watch<AccessibilityService>();
    
    return Semantics(
      label: 'Tier ${widget.item.tier} item',
      hint: (a11y.voiceOverHints || a11y.voiceControlHints)
          ? 'Double tap to select. Long-press to auto-select if unlocked.'
          : null,
      onTapHint: a11y.voiceControlHints ? 'Select item' : null,
      onLongPressHint: a11y.voiceControlHints ? 'Auto-select nearby items' : null,
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: widget.isHighlighted ? 1.18 : 1.0,
          duration: Duration(milliseconds: a11y.reducedMotion ? 0 : 200),
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
                      width: a11y.highContrast ? 3 : 2,
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
            child: Stack(
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (a11y.reducedMotion)
                          UniqueItemGlyph(item: widget.item, size: size)
                        else
                          ScaleTransition(
                            scale: widget.isHighlighted ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                            child: UniqueItemGlyph(item: widget.item, size: size),
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
                if (widget.isHighlighted && a11y.differentiateWithoutColor)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.texture, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
