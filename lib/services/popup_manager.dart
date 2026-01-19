import 'dart:async';

import 'package:flutter/material.dart';

/// Centralized popup orchestration.
///
/// Goals:
/// - Ensure we don't stack multiple modal surfaces at once.
/// - Provide a single API for bottom sheets, dialogs, and lightweight toasts.
/// - Keep UI code consistent across screens.
class PopupManager extends ChangeNotifier {
  Future<void> _queue = Future<void>.value();
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  /// Enqueue a popup operation so only one runs at a time.
  Future<T?> enqueue<T>(Future<T?> Function() op) {
    final completer = Completer<T?>();
    _queue = _queue.then((_) async {
      try {
        final res = await op();
        if (!completer.isCompleted) completer.complete(res);
      } catch (e) {
        debugPrint('PopupManager.enqueue failed: $e');
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    Color? backgroundColor,
  }) {
    return enqueue(() async {
      if (!context.mounted) return null;
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        backgroundColor: backgroundColor,
        builder: builder,
      );
    });
  }

  Future<T?> showAppDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return enqueue(() async {
      if (!context.mounted) return null;
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    });
  }

  /// Shows a dialog but **does not** wait for it to be dismissed.
  ///
  /// Useful for progress spinners where the caller will dismiss later.
  void showDialogNonBlocking({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    bool useRootNavigator = true,
  }) {
    unawaited(
      enqueue(() async {
        if (!context.mounted) return null;
        try {
          showDialog<void>(
            context: context,
            barrierDismissible: barrierDismissible,
            useRootNavigator: useRootNavigator,
            builder: builder,
          );
        } catch (e) {
          debugPrint('PopupManager.showDialogNonBlocking failed: $e');
        }
        return null;
      }),
    );
  }

  /// Best-effort attempt to close the top-most route on the root navigator.
  ///
  /// This is useful for progress spinners shown via [showDialogNonBlocking]
  /// where the caller needs to dismiss later, and it avoids hard crashes when
  /// the route stack isn't in the expected state.
  Future<bool> closeTopMostPopup(BuildContext context) async {
    if (!context.mounted) return false;
    try {
      return await Navigator.of(context, rootNavigator: true).maybePop();
    } catch (e) {
      debugPrint('PopupManager.closeTopMostPopup failed: $e');
      return false;
    }
  }

  /// Lightweight center toast using a general dialog.
  ///
  /// Uses an [OverlayEntry] so it never blocks taps on the underlying UI.
  Future<void> showCenterToast(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    return enqueue<void>(() async {
      if (!context.mounted) return null;
      final overlay = Overlay.of(context, rootOverlay: true);
      if (overlay == null) return null;

      // Remove any existing toast so we never stack invisible modal barriers.
      _toastTimer?.cancel();
      _toastTimer = null;
      _toastEntry?.remove();
      _toastEntry = null;

      final cs = Theme.of(context).colorScheme;
      final bg = cs.surfaceContainerHighest.withValues(alpha: 0.95);
      final border = cs.outline.withValues(alpha: 0.25);
      final onBg = cs.onSurface;

      _toastEntry = OverlayEntry(
        builder: (ctx) {
          // A toast should never steal taps.
          return IgnorePointer(
            ignoring: true,
            child: _CenterToastView(message: message, icon: icon, background: bg, border: border, foreground: onBg),
          );
        },
      );
      overlay.insert(_toastEntry!);

      _toastTimer = Timer(duration, () {
        try {
          _toastEntry?.remove();
        } catch (_) {}
        _toastEntry = null;
        _toastTimer = null;
      });

      return null;
    });
  }
}

class _CenterToastView extends StatefulWidget {
  const _CenterToastView({required this.message, required this.icon, required this.background, required this.border, required this.foreground});
  final String message;
  final IconData? icon;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  State<_CenterToastView> createState() => _CenterToastViewState();
}

class _CenterToastViewState extends State<_CenterToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return Center(
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final t = anim.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: (0.92 + 0.08 * t).clamp(0.92, 1.0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: widget.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.foreground, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: widget.foreground, fontWeight: FontWeight.w600),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
