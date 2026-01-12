import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mergeworks/services/log_service.dart';
import 'package:mergeworks/services/accessibility_service.dart';

/// Displays short-lived captions when Accessibility captions are enabled.
/// Listens to LogService lines that start with 'SFX:' or 'MUSIC:'.
class CaptionsOverlay extends StatefulWidget {
  const CaptionsOverlay({super.key});

  @override
  State<CaptionsOverlay> createState() => _CaptionsOverlayState();
}

class _CaptionsOverlayState extends State<CaptionsOverlay> {
  String? _message;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityService>();
    if (!a11y.captionsEnabled) {
      return const SizedBox.shrink();
    }
    return Selector<LogService, String?>(
      selector: (_, log) => log.last(1).isNotEmpty ? log.last(1).first : null,
      builder: (context, lastLine, child) {
        if (lastLine != null && (lastLine.contains('SFX:') || lastLine.contains('MUSIC:'))) {
          final colon = lastLine.indexOf('|');
          final content = colon >= 0 ? lastLine.substring(colon + 1).trim() : lastLine;
          _show(content.replaceFirst('SFX:', '').replaceFirst('MUSIC:', '').trim());
        }
        return AnimatedSlide(
          duration: Duration(milliseconds: a11y.reducedMotion ? 0 : 220),
          offset: _message == null ? const Offset(0, -1) : Offset.zero,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: a11y.reducedMotion ? 0 : 220),
            opacity: _message == null ? 0 : 1,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _message == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            _message!,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _show(String msg) {
    if (!mounted) return;
    setState(() => _message = msg);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _message = null);
    });
  }
}
