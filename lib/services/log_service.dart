import 'dart:async';
import 'package:flutter/foundation.dart';

/// LogService captures recent log lines (print/debugPrint/Flutter errors) in a ring buffer.
/// Use LogService.instance to access the singleton. Provides last(n) to retrieve recent lines.
class LogService extends ChangeNotifier {
  LogService._internal({this.capacity = 1000});
  static final LogService instance = LogService._internal();

  final int capacity;
  final List<String> _buffer = <String>[];

  /// Adds a line to the buffer with timestamp.
  void add(String line) {
    final ts = DateTime.now().toIso8601String();
    final entry = '$ts | $line';
    _buffer.add(entry);
    if (_buffer.length > capacity) {
      // Trim oldest entries to maintain capacity
      _buffer.removeRange(0, _buffer.length - capacity);
    }
    notifyListeners();
  }

  /// Returns a copy of the most recent [n] lines (or all if fewer available).
  List<String> last(int n) {
    if (_buffer.isEmpty) return const <String>[];
    if (n >= _buffer.length) return List<String>.from(_buffer);
    return List<String>.from(_buffer.sublist(_buffer.length - n));
  }

  /// Sets up global hooks to capture print, debugPrint, and FlutterError.
  /// Call this at app startup within a zoned environment.
  static void hookGlobalLogging() {
    final log = LogService.instance;

    // Capture debugPrint
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) log.add(message);
      debugPrintSynchronously(message, wrapWidth: wrapWidth);
    };

    // Capture Flutter framework errors
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      log.add('FlutterError: ${details.exceptionAsString()}');
      if (details.stack != null) {
        log.add(details.stack.toString());
      }
      // Forward to previous handler/console
      if (prevOnError != null) {
        prevOnError(details);
      } else {
        FlutterError.dumpErrorToConsole(details);
      }
    };
  }

  /// Returns a ZoneSpecification that captures print() output.
  static ZoneSpecification zoneSpecForPrintCapture() => ZoneSpecification(
        print: (self, parent, zone, line) {
          LogService.instance.add(line);
          parent.print(zone, line);
        },
      );
}
