import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Firebase service initialization error: $e');
      _isInitialized = true;
      notifyListeners();
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
