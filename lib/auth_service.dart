import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // Use foundation for web-safe platform checks!

typedef AppleSignInCallback = Future<AuthorizationCredentialAppleID> Function({
  required List<AppleIDAuthorizationScopes> scopes,
  WebAuthenticationOptions? webAuthenticationOptions,
  String? nonce,
  String? state,
});

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn? _googleSignIn;
  final AppleSignInCallback _appleSignIn;

  // Inject the dependencies, but default to the real Firebase instances for production
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn, AppleSignInCallback? appleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = _isGoogleSignInSupported()
            ? (googleSignIn ?? GoogleSignIn())
            : googleSignIn,
        _appleSignIn = appleSignIn ?? SignInWithApple.getAppleIDCredential;

  static bool _isGoogleSignInSupported() {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    if (_googleSignIn == null) throw UnsupportedError('Google Sign-In is not supported on this platform.');
    try {
      // 1. Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // 2. Exit if the user cancelled the flow
      if (googleUser == null) return; 
      
      // 3. Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      
      // 4. Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Sign in or link with the credential
      if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
        await _auth.currentUser!.linkWithCredential(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow; // Good practice to rethrow so the UI can catch and show an error!
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserWithEmailAndPassword(String email, String password, String name) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // After creating the user, update their profile with the provided name and reload
    await userCredential.user?.updateDisplayName(name);
    await userCredential.user?.reload();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signInWithApple() async {
    try {
      WebAuthenticationOptions? webOptions;
      // Apple Sign In on Web and Android requires a Service ID and redirect URI
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
        final clientId = dotenv.env['APPLE_WEB_CLIENT_ID'];
        final redirectUri = dotenv.env['APPLE_WEB_REDIRECT_URI'];

        if (clientId == null || redirectUri == null) {
          throw Exception('Apple Sign-In environment variables (APPLE_WEB_CLIENT_ID, APPLE_WEB_REDIRECT_URI) are not set for this platform.');
        }

        webOptions = WebAuthenticationOptions(
          clientId: clientId,
          redirectUri: Uri.parse(redirectUri),
        );
      }

      // 1. Request credential from Apple
      final AuthorizationCredentialAppleID appleCredential = await _appleSignIn(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webOptions,
      );

      // 2. Create the Firebase credential
      final AuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Link or Sign-In
      if (_auth.currentUser != null && _auth.currentUser!.isAnonymous) {
        await _auth.currentUser!.linkWithCredential(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Apple Sign-In Error: $e");
      rethrow;
    }
  }

  Future<void> signInAsGuest() async {
    UserCredential userCred = await _auth.signInAnonymously();
    await userCred.user?.updateDisplayName("Guest");
    await userCred.user?.reload();
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}