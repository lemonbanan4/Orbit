import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/auth_service.dart';
import 'dart:async';
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
        // Notification permission used to be requested right here, via
        // _setupFCM() below, on every single auth-state change -- including
        // the automatic anonymous sign-in that happens before a brand new
        // user ever sees onboarding. iOS only ever shows the real system
        // dialog once per install, so this fired first and "used up" the
        // ask with zero context, defeating the contextual soft-ask in
        // MainNavigationScreen (showNotificationPrePrompt), which already
        // covers every user path identically. _setupFCM did nothing else
        // (its only other code was commented out), so it's removed rather
        // than fixed in place.
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier(''); // Clear on logout
        // Ensure we reset Pro status so the next session/guest starts clean
        _isPro = false;
      }

      notifyListeners();
    });
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
  //
  // Deliberately does NOT catch its own errors here (unlike an earlier
  // version) -- every sibling sign-in method (signInWithGoogle,
  // signInWithApple, signInWithEmailAndPassword) just lets a failure
  // propagate up to login_screen.dart's _performSignIn, which logs it to
  // Crashlytics and shows the user an error SnackBar. This one used to
  // swallow its own exception with only a debugPrint, so a failed guest
  // sign-in (network error, or Firebase Auth left in an inconsistent
  // state) looked like the button silently doing nothing, with zero
  // diagnostic signal anywhere.
  Future<void> signInAsGuest() async {
    await _authService.signInAsGuest();
    // Firebase will automatically update the user state,
    // and your main.dart AuthWrapper will push them to the onboarding!
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
