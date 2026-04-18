import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import 'dart:async';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService;
  
  StreamSubscription<User?>? _authStateSubscription;
  User? _user;
  User? get user => _user;

  // Use constructor injection, but default to the real service if none is provided
  AppAuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    // This automatically listens to see if the user logs in or out!
    _authStateSubscription = _authService.authStateChanges.listen((User? newUser) {
      _user = newUser;
      
      // Attach the user's ID to Crashlytics so we know exactly who experienced an error!
      if (newUser != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(newUser.uid);
        FirebaseCrashlytics.instance.setCustomKey('is_anonymous', newUser.isAnonymous);
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier(''); // Clear on logout
      }
      
      notifyListeners();
    });
  }
    
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    await _authService.signInWithGoogle();
  }

  Future<void> signInWithApple() async {
    await _authService.signInWithApple();
  }

  // EMAIL / PASSWORD LOGIN
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _authService.signInWithEmailAndPassword(email, password);
  }

  // EMAIL / PASSWORD SIGN UP
  Future<void> createUserWithEmailAndPassword(String email, String password, String name) async {
    await _authService.createUserWithEmailAndPassword(email, password, name);
  }

  // PASSWORD RESET
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  // ANONYMOUS GUEST LOGIN
  Future<void> signInAsGuest() async {
    try {
      await _authService.signInAsGuest();
      // Firebase will automatically update the user state,
      // and your main.dart AuthWrapper will push them to the onboarding!
    } catch (e) {
      debugPrint("Error signing in anonymously: $e");
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}