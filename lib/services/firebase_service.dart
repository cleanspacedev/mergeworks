import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseFunctions? _functions;
  
  User? _currentUser;
  bool _isInitialized = false;

  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.uid;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  FirebaseFirestore get firestore => _firestore;

  Future<void> initialize() async {
    try {
      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) {
        _currentUser = user;
        debugPrint('Auth state changed: ${user?.uid ?? "null"}');
        notifyListeners();
      });

      // Check current user
      _currentUser = _auth.currentUser;
      
      // If no user, sign in anonymously
      if (_currentUser == null) {
        debugPrint('No user found, signing in anonymously...');
        await signInAnonymously();
      } else {
        debugPrint('User already signed in: ${_currentUser!.uid}');
      }

      // Initialize Cloud Functions (default region used by our functions)
      _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      debugPrint('Firebase Functions initialized for region us-central1');
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Firebase service initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Calls the test callable function `ping` deployed in us-central1.
  /// Returns the message string, or an error description if failed.
  Future<String> callTestPing({String name = 'tester'}) async {
    try {
      final fns = _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
      final result = await fns.httpsCallable('ping').call(<String, dynamic>{'name': name});
      final data = result.data as Map<dynamic, dynamic>;
      final msg = data['message']?.toString() ?? 'No message';
      debugPrint('ping() -> ' + msg);
      return msg;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions error: code=${e.code}, message=${e.message}');
      return 'Error: ' + (e.message ?? e.code);
    } catch (e) {
      debugPrint('Unexpected error calling ping: $e');
      return 'Unexpected error: ' + e.toString();
    }
  }

  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _currentUser = userCredential.user;
      debugPrint('Anonymous sign-in successful: ${_currentUser?.uid}');
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      debugPrint('User signed out');
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  // Helper method to get a user-scoped Firestore reference
  CollectionReference getUserCollection(String collectionName) {
    if (userId == null) {
      throw Exception('No authenticated user');
    }
    return _firestore.collection(collectionName);
  }
}
