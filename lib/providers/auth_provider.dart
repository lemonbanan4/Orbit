import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/dev_overrides.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService;

  // global pro status that can be updated from anywhere in the app, and will persist across sessions
  bool? _isPro;
  bool? get isPro => DevOverrides.isProUnlocked ? true : _isPro;
  void updateProStatus(bool? isPro) {
    _isPro = isPro;
    notifyListeners();
  }

  StreamSubscription<User?>? _authStateSubscription;
  User? _user;
  User? get user => _user;

  // Use constructor injection, but default to the real service if none is provided
  AppAuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    // This automatically listens to see if the user logs in or out!
    _authStateSubscription = _authService.authStateChanges.listen((
      User? newUser,
    ) {
      _user = newUser;

      // Attach the user's ID to Crashlytics so we know exactly who experienced an error!
      if (newUser != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(newUser.uid);
        FirebaseCrashlytics.instance.setCustomKey(
          'is_anonymous',
          newUser.isAnonymous,
        );

        // Setup push notifications and write them directly to the inbox
        _setupFCM(newUser.uid);
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier(''); // Clear on logout
        // Ensure we reset Pro status so the next session/guest starts clean
        _isPro = false;
      }

      notifyListeners();
    });
  }

  Future<void> _setupFCM(String uid) async {
    if (kIsWeb) {
      return; // Prevent Web crashes if service workers aren't configured
    }

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // Listen to foreground messages and log them directly to Firestore!
      // FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      //   if (message.notification != null) {
      //     await FirebaseFirestore.instance
      //         .collection('users')
      //         .doc(uid)
      //         .collection('notifications')
      //         .add({
      //           'title': message.notification!.title ?? 'New Alert',
      //           'message': message.notification!.body ?? '',
      //           'type': message.data['type'] ?? 'system',
      //           'timestamp': FieldValue.serverTimestamp(),
      //         });
      //   }
      // });
    } catch (e) {
      debugPrint('Failed to setup FCM: $e');
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // Returns whether this sign-in just created a brand new account.
  Future<bool> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  // Returns whether this sign-in just created a brand new account.
  Future<bool> signInWithApple() async {
    return await _authService.signInWithApple();
  }

  // EMAIL / PASSWORD LOGIN
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _authService.signInWithEmailAndPassword(email, password);
  }

  // EMAIL / PASSWORD SIGN UP
  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    await _authService.createUserWithEmailAndPassword(email, password, name);
  }

  // LINK EMAIL / PASSWORD TO GUEST
  Future<void> linkWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    await _authService.linkWithEmailAndPassword(email, password, name);
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
