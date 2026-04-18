import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:orbit/services/auth_service.dart'; // Adjust if your import path is slightly different

// 1. Create the Mock Classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}
class MockAuthorizationCredentialAppleID extends Mock implements AuthorizationCredentialAppleID {}

// 2. Create a Fake for classes we need to pass into methods using any()
class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  setUpAll(() {
    // This allows us to use `any()` when a method expects an AuthCredential
    registerFallbackValue(FakeAuthCredential());
  });

  late MockFirebaseAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthService authService;
  
  // Callback mock for Apple Sign In
  late Future<AuthorizationCredentialAppleID> Function({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) mockAppleSignIn;

  // setUp runs before EVERY individual test
  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    
    mockAppleSignIn = ({required List<AppleIDAuthorizationScopes> scopes, WebAuthenticationOptions? webAuthenticationOptions, String? nonce, String? state}) async {
      return MockAuthorizationCredentialAppleID();
    };
    
    // Inject the mocks into our service!
    authService = AuthService(
      auth: mockAuth,
      googleSignIn: mockGoogleSignIn,
      appleSignIn: mockAppleSignIn,
    );
  });

  group('AuthService', () {
    test('signInAsGuest creates an anonymous user and sets the name to Guest', () async {
      // Arrange: Set up the specific mocks needed for this test
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();

      when(() => mockAuth.signInAnonymously()).thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async {});
      when(() => mockUser.reload()).thenAnswer((_) async {});

      // Act: Call the method we are testing
      await authService.signInAsGuest();

      // Assert: Verify the right Firebase methods were called in order
      verify(() => mockAuth.signInAnonymously()).called(1);
      verify(() => mockUser.updateDisplayName("Guest")).called(1);
      verify(() => mockUser.reload()).called(1);
    });

    test('signInWithGoogle completes the full authentication flow', () async {
      // Arrange: Create the intermediate mock objects
      final mockGoogleUser = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      final mockUserCredential = MockUserCredential();
      
      // 1. Mock the authentication prompt
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
      
      // 2. Mock getting the auth tokens
      when(() => mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('dummy_id_token');
      when(() => mockGoogleAuth.accessToken).thenReturn('dummy_access_token');

      // 3. Mock the final Firebase sign-in step
      when(() => mockAuth.currentUser).thenReturn(null); // Simulate not being logged in as a guest
      when(() => mockAuth.signInWithCredential(any())).thenAnswer((_) async => mockUserCredential);

      // Act
      await authService.signInWithGoogle();

      // Assert: Verify we successfully created a credential and passed it to Firebase
      verify(() => mockAuth.signInWithCredential(any())).called(1);
    });

    test('signInWithGoogle aborts early if Google Sign-In is cancelled', () async {
      // Arrange: Simulate user cancelling the sign-in (returns null)
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      // Act
      await authService.signInWithGoogle();

      // Verify: Ensure Firebase was NEVER called because the flow aborted early!
      verifyNever(() => mockAuth.signInWithCredential(any()));
    });

    test('signInWithApple completes the full authentication flow', () async {
      // Arrange
      final mockAppleCredential = MockAuthorizationCredentialAppleID();
      final mockUserCredential = MockUserCredential();

      mockAppleSignIn = ({required List<AppleIDAuthorizationScopes> scopes, WebAuthenticationOptions? webAuthenticationOptions, String? nonce, String? state}) async {
        return mockAppleCredential;
      };
      authService = AuthService(auth: mockAuth, googleSignIn: mockGoogleSignIn, appleSignIn: mockAppleSignIn);

      when(() => mockAppleCredential.identityToken).thenReturn('dummy_apple_id_token');
      when(() => mockAppleCredential.authorizationCode).thenReturn('dummy_apple_auth_code');

      // 2. Mock Firebase sign-in
      when(() => mockAuth.currentUser).thenReturn(null); // Simulate not being a guest
      when(() => mockAuth.signInWithCredential(any())).thenAnswer((_) async => mockUserCredential);

      // Act
      await authService.signInWithApple();

      // Assert: Verify Firebase was called with the credential
      verify(() => mockAuth.signInWithCredential(any())).called(1);
    });

    test('signOut calls both GoogleSignIn and FirebaseAuth sign out methods', () async {
      // Arrange
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      // Act
      await authService.signOut();

      // Assert
      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockAuth.signOut()).called(1);
    });

    test('signInWithEmailAndPassword delegates to FirebaseAuth', () async {
      // Arrange
      final mockUserCredential = MockUserCredential();
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);

      // Act
      await authService.signInWithEmailAndPassword('test@orbit.com', 'password123');

      // Assert
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'password123',
          )).called(1);
    });

    test('signInWithEmailAndPassword allows FirebaseAuthExceptions to bubble up', () async {
      // Arrange
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'wrong_password',
          )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      // Act & Assert
      expect(
        () => authService.signInWithEmailAndPassword('test@orbit.com', 'wrong_password'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('signInWithGoogle throws error on Firebase network failure', () async {
      // Arrange
      final mockGoogleUser = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleUser);
      when(() => mockGoogleUser.authentication).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('dummy_id_token');
      when(() => mockGoogleAuth.accessToken).thenReturn('dummy_access_token');
      
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.signInWithCredential(any()))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      // Act & Assert
      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('createUserWithEmailAndPassword creates user, updates name, and reloads', () async {
      // Arrange
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'password123',
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockUser.updateDisplayName(any())).thenAnswer((_) async {});
      when(() => mockUser.reload()).thenAnswer((_) async {});

      // Act
      await authService.createUserWithEmailAndPassword('test@orbit.com', 'password123', 'Commander');

      // Assert
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'password123',
          )).called(1);
      verify(() => mockUser.updateDisplayName('Commander')).called(1);
      verify(() => mockUser.reload()).called(1);
    });

    test('createUserWithEmailAndPassword allows FirebaseAuthExceptions to bubble up', () async {
      // Arrange
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'test@orbit.com',
            password: 'password123',
          )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

      // Act & Assert
      expect(
        () => authService.createUserWithEmailAndPassword('test@orbit.com', 'password123', 'Commander'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('sendPasswordResetEmail delegates to FirebaseAuth', () async {
      // Arrange
      when(() => mockAuth.sendPasswordResetEmail(email: 'test@orbit.com'))
          .thenAnswer((_) async {});

      // Act
      await authService.sendPasswordResetEmail('test@orbit.com');

      // Assert
      verify(() => mockAuth.sendPasswordResetEmail(email: 'test@orbit.com')).called(1);
    });

    test('sendPasswordResetEmail allows FirebaseAuthExceptions to bubble up', () async {
      // Arrange
      when(() => mockAuth.sendPasswordResetEmail(email: 'test@orbit.com'))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      // Act & Assert
      expect(
        () => authService.sendPasswordResetEmail('test@orbit.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });
}