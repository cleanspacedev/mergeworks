import 'package:flutter/material.dart';
import 'package:mergeworks/models/game_item.dart';
import 'package:mergeworks/theme.dart';
import 'package:mergeworks/widgets/unique_item_glyph.dart';
import 'package:provider/provider.dart';
import 'package:mergeworks/services/accessibility_service.dart';

class GridItemWidget extends StatefulWidget {
  final GameItem item;
  final bool isHighlighted;
  /// When true, the cell shows a subtle pulse to indicate it could complete
  /// a merge (e.g. player has 2-of-3 selected).
  final bool isHintCandidate;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GridItemWidget({
    super.key,
    required this.item,
    this.isHighlighted = false,
    this.isHintCandidate = false,
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
    final cs = Theme.of(context).colorScheme;

    final bool shouldPulse = widget.isHintCandidate && !widget.isHighlighted;
    
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
          scale: widget.isHighlighted ? 1.18 : (shouldPulse && !a11y.reducedMotion ? 1.02 : 1.0),
          duration: Duration(milliseconds: a11y.reducedMotion ? 0 : 200),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isHighlighted
                    ? [
                      cs.secondary.withValues(alpha: 0.3),
                      cs.tertiary.withValues(alpha: 0.3),
                    ]
                    : [
                      cs.primaryContainer.withValues(alpha: 0.5),
                      cs.surfaceContainerHighest,
                    ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: widget.isHighlighted
                  ? Border.all(
                      color: cs.secondary,
                      width: a11y.highContrast ? 3 : 2,
                    )
                  : (shouldPulse ? Border.all(color: cs.secondary.withValues(alpha: 0.25), width: 1.5) : null),
              boxShadow: widget.isHighlighted
                  ? [
                      BoxShadow(
                        color: cs.secondary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : (shouldPulse
                      ? [
                          BoxShadow(
                            color: cs.secondary.withValues(alpha: a11y.reducedMotion ? 0.0 : 0.18),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ]
                      : null),
            ),
            child: Stack(
              children: [
                if (shouldPulse && !a11y.reducedMotion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 0.18, end: 0.0).animate(
                          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            gradient: RadialGradient(
                              colors: [
                                cs.secondary.withValues(alpha: 0.35),
                                cs.secondary.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.85],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                            color: cs.onSurfaceVariant,
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
                    child: Icon(Icons.texture, size: 16, color: cs.onSurfaceVariant),
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
