// ignore_for_file: undefined_method
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Use foundation for web-safe platform checks!
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

typedef AppleSignInCallback =
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
      WebAuthenticationOptions? webAuthenticationOptions,
      String? nonce,
      String? state,
    });

// Moved the default implementation out of the constructor to simplify the syntax
// and prevent analyzer parsing errors.
Future<AuthorizationCredentialAppleID> _defaultAppleSignIn({
  required List<AppleIDAuthorizationScopes> scopes,
  WebAuthenticationOptions? webAuthenticationOptions,
  String? nonce,
  String? state,
}) => SignInWithApple.getAppleIDCredential(
  scopes: scopes,
  webAuthenticationOptions: webAuthenticationOptions,
  nonce: nonce,
  state: state,
);

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn? _googleSignIn;
  final AppleSignInCallback _appleSignIn;
  bool _isGoogleInitialized = false;

  // Inject the dependencies, but default to the real Firebase instances for production
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    AppleSignInCallback? appleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
           (_isGoogleSignInSupported() ? GoogleSignIn.instance : null),
       _appleSignIn = appleSignIn ?? _defaultAppleSignIn;

  static bool _isGoogleSignInSupported() {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Returns whether this sign-in just created a brand new account (vs. a
  // returning user), so the UI can decide whether to show onboarding/welcome
  // screens or just go straight into the app.
  Future<bool> signInWithGoogle() async {
    // Assign to a local variable to enable Dart's null-safety type promotion
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform.',
      );
    }
    try {
      if (!_isGoogleInitialized) {
        await googleSignIn.initialize();
        _isGoogleInitialized = true;
      }

      // 1. Trigger the authentication flow
      GoogleSignInAccount googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw Exception('Sign-in cancelled by user.');
        }
        rethrow;
      } on PlatformException catch (e) {
        if (e.code == 'sign_in_canceled') {
          throw Exception('Sign-in cancelled by user.');
        }
        rethrow;
      } catch (e, stackTrace) {
        debugPrint("Google Sign-In failed: $e\n$stackTrace");
        throw Exception('Sign-in failed: $e');
      }

      // 3. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 4. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 5. Sign in or link with the credential
      final isNewUser = await _signInOrLink(credential);

      if (_auth.currentUser != null) {
        // Google's credential doesn't automatically populate the Firebase
        // Auth user's displayName, so set it explicitly (same as email
        // sign-up already does) — otherwise currentUser.displayName stays
        // null and callers fall back to a generic placeholder name.
        // Best-effort: must not block _ensureUserDocument below (see the
        // same fix in createUserWithEmailAndPassword) -- a transient
        // failure here shouldn't leave an authenticated user with no
        // Firestore doc.
        try {
          if (googleUser.displayName != null &&
              _auth.currentUser!.displayName != googleUser.displayName) {
            await _auth.currentUser!.updateDisplayName(
              googleUser.displayName,
            );
          }
        } catch (e) {
          debugPrint('Non-fatal error setting Google display name: $e');
        }
        await _ensureUserDocument(
          _auth.currentUser!,
          isGuest: false,
          name: googleUser.displayName,
          email: googleUser.email,
          photoUrl: googleUser.photoUrl,
        );
      }

      return isNewUser;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow; // Good practice to rethrow so the UI can catch and show an error!
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (_auth.currentUser != null) {
      await _ensureUserDocument(_auth.currentUser!, isGuest: false);
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = userCredential.user;
    if (user == null) return;

    // Best-effort -- these three used to run before _ensureUserDocument,
    // so a transient failure in any of them (sendEmailVerification in
    // particular: Firebase actively rate-limits it) left a real Auth
    // account with no Firestore doc at all. The UI shows that as a
    // generic "sign up failed" error, but the account genuinely exists
    // now -- retrying "Create Orbit" then fails with email-already-in-use
    // with no working doc ever getting created. Creating the doc is the
    // one step that must not be skipped; the rest can silently degrade.
    try {
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      await user.reload();
    } catch (e) {
      debugPrint('Non-fatal error finishing account setup: $e');
    }

    await _ensureUserDocument(user, isGuest: false, name: name, email: email);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Returns whether this sign-in just created a brand new account (vs. a
  // returning user), so the UI can decide whether to show onboarding/welcome
  // screens or just go straight into the app.
  Future<bool> signInWithApple() async {
    try {
      WebAuthenticationOptions? webOptions;
      // Apple Sign In on Web and Android requires a Service ID and redirect URI
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
        final clientId = dotenv.env['APPLE_WEB_CLIENT_ID'];
        final redirectUri = dotenv.env['APPLE_WEB_REDIRECT_URI'];

        if (clientId == null || redirectUri == null) {
          throw Exception(
            'Apple Sign-In environment variables (APPLE_WEB_CLIENT_ID, APPLE_WEB_REDIRECT_URI) are not set for this platform.',
          );
        }

        webOptions = WebAuthenticationOptions(
          clientId: clientId,
          redirectUri: Uri.parse(redirectUri),
        );
      }

      // Generate cryptographic nonce for Firebase Apple Sign-In
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // 1. Request credential from Apple
      final AuthorizationCredentialAppleID appleCredential = await _appleSignIn(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webOptions,
        nonce: nonce,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('Failed to retrieve identity token from Apple.');
      }

      // 2. Create the Firebase credential
      final AuthCredential credential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      // 3. Link or Sign-In
      final isNewUser = await _signInOrLink(credential);

      if (_auth.currentUser != null) {
        // Apple only ever provides givenName/familyName on the very first
        // authorization for this Apple ID + app, so this may be empty on
        // subsequent sign-ins — only update when we actually have a name,
        // never clobber a previously-set displayName with a blank one.
        final givenName = appleCredential.givenName ?? '';
        final familyName = appleCredential.familyName ?? '';
        final name = '$givenName $familyName'.trim();
        // Best-effort: must not block _ensureUserDocument below.
        try {
          if (name.isNotEmpty && _auth.currentUser!.displayName != name) {
            await _auth.currentUser!.updateDisplayName(name);
          }
        } catch (e) {
          debugPrint('Non-fatal error setting Apple display name: $e');
        }
        await _ensureUserDocument(
          _auth.currentUser!,
          isGuest: false,
          name: name.isNotEmpty ? name : null,
          email: appleCredential.email,
          photoUrl: _auth.currentUser!.photoURL,
        );
      }

      return isNewUser;
    } catch (e) {
      debugPrint("Apple Sign-In Error: $e");
      rethrow;
    }
  }

  Future<void> linkWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    // Generate an Email Auth Credential
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    // Pass it to your existing linking/merging pipeline!
    await _signInOrLink(credential);

    if (_auth.currentUser != null) {
      // Best-effort: must not block _ensureUserDocument below.
      try {
        await _auth.currentUser!.updateDisplayName(name);
      } catch (e) {
        debugPrint('Non-fatal error setting display name on link: $e');
      }
      await _ensureUserDocument(
        _auth.currentUser!,
        isGuest: false,
        name: name,
        email: email,
      );
    }
  }

  Future<void> signInAsGuest() async {
    UserCredential userCred = await _auth.signInAnonymously();
    final user = userCred.user;
    if (user == null) return;
    // Best-effort: must not block _ensureUserDocument below.
    try {
      await user.updateDisplayName("Guest");
      await user.reload();
    } catch (e) {
      debugPrint('Non-fatal error finishing guest setup: $e');
    }
    await _ensureUserDocument(user, isGuest: true);
  }

  Future<void> signOut() async {
    // Conditional invocation is cleaner and satisfies the compiler!
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  // --- Helpers for Authentication & Linking ---
  // Returns whether this credential just created a brand new account, so
  // callers can tell a genuine sign-up from a returning user signing back
  // in (they should NOT be sent through onboarding/welcome screens again).
  Future<bool> _signInOrLink(AuthCredential credential) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        await currentUser.linkWithCredential(credential);
        // Linking a credential onto an existing guest account never counts
        // as "new" — the guest already went through onboarding.
        return false;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          final guestUid = currentUser.uid;

          // Sign into the existing account
          final userCred = await _auth.signInWithCredential(credential);
          final newUid = userCred.user?.uid;

          // Migrate Firestore data before cleaning up
          if (newUid != null && guestUid != newUid) {
            await _migrateGuestData(guestUid, newUid);
          }

          // Clean up the abandoned guest account to prevent database clutter
          try {
            await currentUser.delete();
          } catch (_) {}

          return false;
        } else if (e.code == 'provider-already-linked') {
          // Safe to ignore, the account is already linked
          return false;
        } else if (e.code == 'user-disabled') {
          throw Exception(
            'This account has been disabled by an administrator.',
          );
        } else {
          rethrow;
        }
      }
    } else {
      try {
        final userCred = await _auth.signInWithCredential(credential);
        return userCred.additionalUserInfo?.isNewUser ?? false;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-disabled') {
          throw Exception(
            'This account has been disabled by an administrator.',
          );
        }
        rethrow;
      }
    }
  }

  // --- Helpers for Data Migration ---
  Future<void> _migrateGuestData(String guestUid, String newUid) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final guestDoc = await usersRef.doc(guestUid).get();

    if (guestDoc.exists) {
      final guestData = guestDoc.data() ?? {};

      // Remove fields that shouldn't overwrite the permanent account's identity
      guestData.remove('isGuest');
      guestData.remove('createdAt');
      guestData.remove('email');
      guestData.remove('name');

      // Merge the guest's progress into the permanent account
      await usersRef.doc(newUid).set(guestData, SetOptions(merge: true));

      // Migrate known subcollections (shallow copy doesn't move these automatically).
      // Must cover every subcollection users can actually write to (see the
      // `match` blocks in firestore.rules) -- this previously missed
      // journal_entries, cache, fairy_history, skipped_sessions, and
      // friend_requests, so a guest who journaled, chatted with the fairy,
      // or skipped a session lost all of it the moment they linked an account.
      final subcollections = [
        'habits',
        'notifications',
        'coaching_notes',
        'journal_entries',
        'cache',
        'fairy_history',
        'skipped_sessions',
        'friend_requests',
      ];
      for (final subcollection in subcollections) {
        final guestSubRef = usersRef.doc(guestUid).collection(subcollection);
        final newSubRef = usersRef.doc(newUid).collection(subcollection);

        final guestDocs = await guestSubRef.get();
        if (guestDocs.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in guestDocs.docs) {
            batch.set(
              newSubRef.doc(doc.id),
              doc.data(),
              SetOptions(merge: true),
            );
            batch.delete(doc.reference); // Delete the old guest sub-document
          }
          await batch.commit();
        }
      }

      // Delete the old guest document
      await usersRef.doc(guestUid).delete();
    }
  }

  // --- Helpers for User Document Management ---
  Future<void> _ensureUserDocument(
    User user, {
    required bool isGuest,
    String? name,
    String? email,
    String? photoUrl,
  }) async {
    // firestore.rules caps name at 60 chars. This is the single funnel for
    // every signup path (email/password, Google, Apple, guest) including
    // OAuth display names the client-side name regex never validates -- an
    // unclamped long name here throws on write, leaving a real Auth account
    // with no Firestore doc and no retry path (retry just hits
    // email-already-in-use).
    if (name != null && name.length > 60) {
      name = name.substring(0, 60);
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final doc = await userRef.get();

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("Failed to fetch FCM token: $e");
    }

    if (!doc.exists) {
      // Initialize fresh data for a new user/guest
      await userRef.set({
        'isGuest': isGuest,
        'createdAt': FieldValue.serverTimestamp(),
        'streakCount': 0,
        'completedMilestones': [],
        'achievements': [],
        'name': ?name,
        'email': ?email,
        'photoUrl': ?photoUrl,
        'fcmToken': ?fcmToken,
      });
    } else {
      final updates = <String, dynamic>{};
      final existingData = doc.data();

      if (!isGuest) updates['isGuest'] = false;

      if (fcmToken != null && existingData?['fcmToken'] != fcmToken) {
        updates['fcmToken'] = fcmToken;
      }

      if (name != null && existingData?['name'] != name) {
        updates['name'] = name;
      }

      if (email != null && existingData?['email'] != email) {
        updates['email'] = email;
      }

      if (photoUrl != null && existingData?['photoUrl'] != photoUrl) {
        updates['photoUrl'] = photoUrl;
      }

      if (updates.isNotEmpty) {
        await userRef.update(updates);
      }
    }
  }

  // --- Helpers for Apple Sign-In Cryptography ---
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
