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

  /// Lightweight center toast using a general dialog.
  ///
  /// Uses the Navigator overlay so it doesn't require a [TickerProvider].
  Future<void> showCenterToast(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    return enqueue<void>(() async {
      if (!context.mounted) return null;

      final cs = Theme.of(context).colorScheme;
      final bg = cs.surfaceContainerHighest.withValues(alpha: 0.95);
      final border = cs.outline.withValues(alpha: 0.25);
      final onBg = cs.onSurface;

      // Auto-dismiss.
      unawaited(Future.delayed(duration, () {
        try {
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }));

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'toast',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (context, anim, __, ___) {
          final t = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
          return Opacity(
            opacity: t.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: (0.9 + 0.1 * t.value).clamp(0.9, 1.0),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: onBg, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: onBg, fontWeight: FontWeight.w600),
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
            ),
          );
        },
      );
      return null;
    });
  }
}
