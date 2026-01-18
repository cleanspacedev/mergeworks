import 'package:flutter/material.dart';
import 'package:mergeworks/theme.dart';

/// Centers content and constrains its max width on larger screens.
///
/// Use this for most scrollable pages so tablets don't end up with edge-to-edge
/// text and overly wide cards.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxWidth = maxWidth ?? context.contentMaxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
        child: Padding(padding: context.pagePadding, child: child),
      ),
    );
  }
}
