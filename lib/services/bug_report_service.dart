import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mergeworks/services/firebase_service.dart';
import 'package:mergeworks/services/log_service.dart';

/// Service to submit structured bug reports to Firestore.
///
/// It writes two documents per report:
/// - users/{uid}/bug_reports/{userBugId} (user-scoped)
/// - bug_reports/{centralId} (central table)
/// Both docs contain the same payload and cross-link each other with a DocumentReference.
class BugReportService extends ChangeNotifier {
  FirebaseService? _firebaseService;
  set firebaseService(FirebaseService svc) => _firebaseService = svc;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Submits a bug report with a title, description, and optional extra metadata.
  /// Returns the central bug report document id on success, or null on failure.
  Future<String?> submitBugReport({
    required String title,
    required String description,
    Map<String, dynamic>? extras,
  }) async {
    try {
      final fs = _firebaseService;
      if (fs == null || !fs.isAuthenticated || fs.userId == null) {
        debugPrint('BugReportService: cannot submit, user not authenticated.');
        return null;
      }
      final uid = fs.userId!;
      final userEmail = fs.currentUser?.email;

      // Collect last N log lines for context
      final logs = LogService.instance.last(200);

      // Basic environment info without extra packages
      final env = <String, dynamic>{
        'isWeb': kIsWeb,
        'isRelease': kReleaseMode,
        'platform': _platformString(),
        'locale': WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
      };

      final now = Timestamp.now();

      // Pre-create refs so we can cross-link in a single batch
      final userBugRef = _db.collection('users').doc(uid).collection('bug_reports').doc();
      final centralRef = _db.collection('bug_reports').doc();

      final payload = <String, dynamic>{
        'title': title,
        'description': description,
        'status': 'open',
        'createdAt': now,
        'userId': uid,
        if (userEmail != null) 'userEmail': userEmail,
        'env': env,
        if (extras != null) 'extras': extras,
        'logs': logs,
      };

      final batch = _db.batch();

      // Add/update a minimal user doc marker for convenience (optional)
      final userDoc = _db.collection('users').doc(uid);
      batch.set(userDoc, {'lastReportAt': now}, SetOptions(merge: true));

      // Write user-scoped report with back-link to central
      batch.set(userBugRef, {
        ...payload,
        'centralRef': centralRef,
        'centralPath': centralRef.path,
      });

      // Write central report with link to user-scoped doc
      batch.set(centralRef, {
        ...payload,
        'userBugRef': userBugRef,
        'userBugPath': userBugRef.path,
      });

      await batch.commit();
      debugPrint('BugReportService: submitted report ${centralRef.id} (user ref: ${userBugRef.path})');
      return centralRef.id;
    } catch (e) {
      debugPrint('BugReportService: failed to submit bug report: $e');
      return null;
    }
  }

  String _platformString() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }
}
