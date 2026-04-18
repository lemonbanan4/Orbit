import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbit/services/auth_service.dart';

// Import your main.dart file so the test can launch your app
import 'package:orbit/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';

class MockAuthService extends Mock implements AuthService {}
class MockUser extends Mock implements User {}

void main() {
  // 1. Initialize and capture the binding to allow screenshots
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // This runs after each test to ensure a clean state
  tearDown(() async {
    // Use 10.0.2.2 for Android emulators to connect to the host machine's localhost
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    
    // This project ID should match the one your app is running with.
    // You can find it in your .firebaserc file or the emulator startup logs.
    const projectId = 'orbit'; // Replace with your actual project ID if needed

    // Clear all users from the Auth emulator
    final authUri = Uri.parse('http://$host:9099/emulator/v1/projects/$projectId/accounts');
    await http.delete(authUri);

    // Clear all data from the Firestore emulator
    final firestoreUri = Uri.parse('http://$host:8080/emulator/v1/projects/$projectId/databases/(default)/documents');
    await http.delete(firestoreUri);

    // Clear SharedPreferences to ensure a completely fresh start for every test!
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('Unauthenticated user is redirected to LoginScreen', (WidgetTester tester) async {
    // Start the app
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // Verify the LoginScreen is rendered by checking for its explicit ValueKey and text
    expect(find.byKey(const ValueKey('login')), findsOneWidget);
    expect(find.text('Master your habits.\nCommand your day.'), findsOneWidget);
  });

  testWidgets('User can complete onboarding flow as guest', (WidgetTester tester) async {
    // 2. Start the entire app
    await app.launchApp(isTestEnvironment: true);
    
    // pumpAndSettle waits for all initial animations, network requests, and renders to finish
    await tester.pumpAndSettle();

    // Capture a screenshot of the Welcome Screen!
    await binding.takeScreenshot('01_welcome_screen');

    // 3. Verify we are on the initial Login/Onboarding screen
    // (Replace with actual text from your app)
    expect(find.text('Orbit'), findsOneWidget); 

    // 4. Tap the 'Continue as Guest' button
    final guestButton = find.text('Continue as Guest');
    expect(guestButton, findsOneWidget);
    await tester.tap(guestButton);
    
    // Wait for the navigation animation to the next screen to finish
    await tester.pumpAndSettle();

    // 5. Verify we navigated to the Routine Setup screen
    expect(find.text('Setup your routine'), findsOneWidget);
    
    // Capture a screenshot of the Setup Screen
    await binding.takeScreenshot('02_setup_screen');

    // 6. Tap the 'Next' or 'Finish' button
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    
    // 7. Verify the user successfully landed on the Home Screen!
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('User can sign up with email and password', (WidgetTester tester) async {
    // 1. Start the entire app
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 2. Toggle to Sign Up mode
    final signUpToggle = find.text("Don't have an account? Sign Up");
    expect(signUpToggle, findsOneWidget);
    await tester.tap(signUpToggle);
    await tester.pumpAndSettle(); // Wait for the animation to reveal sign-up fields

    // 3. Fill out the registration form
    // We can access the TextFields by the order they appear on the screen
    await tester.enterText(find.byType(TextField).at(0), 'Test Astronaut'); // Name
    await tester.enterText(find.byType(TextField).at(1), 'astronaut@orbit.com'); // Email
    await tester.enterText(find.byType(TextField).at(2), 'Orbit!2024'); // Password
    await tester.enterText(find.byType(TextField).at(3), 'Orbit!2024'); // Confirm Password

    // Hide the keyboard to ensure the submit button and checkbox are tappable
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 4. Accept the Terms of Service
    final termsCheckbox = find.byType(Checkbox);
    await tester.tap(termsCheckbox);
    await tester.pumpAndSettle();

    // 5. Submit the form
    final createAccountButton = find.text('Create Account');
    await tester.tap(createAccountButton);
    
    // Wait for the Firebase Auth emulator to respond and navigation to finish
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 6. Verify we navigated to the Setup screen
    expect(find.text('Setup your routine'), findsOneWidget);
  });

  testWidgets('User can request a password reset email', (WidgetTester tester) async {
    // 1. Start the app
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 2. Enter a valid email address (Email is the 1st TextField in Sign-In mode)
    await tester.enterText(find.byType(TextField).at(0), 'forgot@orbit.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 3. Tap the 'Forgot Password?' button
    final forgotPasswordButton = find.text('Forgot Password?');
    expect(forgotPasswordButton, findsOneWidget);
    await tester.tap(forgotPasswordButton);

    // Wait for the simulated network request and SnackBar animation
    await tester.pumpAndSettle();

    // 4. Verify the success SnackBar appeared
    expect(find.text('Password reset link sent to forgot@orbit.com.'), findsOneWidget);
  });

  testWidgets('User lands on Dashboard if already logged in', (WidgetTester tester) async {
    // 1. Start the app for the first time
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 2. Log in as a guest
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // 3. Complete the setup/onboarding flow to reach the dashboard
    await tester.tap(find.text('Next')); 
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.home_rounded), findsOneWidget); // Confirms we reached the Dashboard

    // 4. Simulate closing and reopening the app!
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 5. Verify we bypassed the Login screen and Onboarding entirely!
    expect(find.byKey(const ValueKey('login')), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('User can sign out from the Dashboard', (WidgetTester tester) async {
    // 1. Preset SharedPreferences to simulate a user who already completed onboarding!
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    // 2. Start the app
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 3. Log in as a guest
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // 4. Verify we bypassed onboarding and went straight to the Dashboard
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    // --- 🚨 ACTION REQUIRED 🚨 ---
    // Since I can't see your Dashboard UI, you will need to uncomment and update 
    // the finders below to match the exact icons/text of your app's Sign Out flow:

    // 5. Navigate to settings/profile (e.g., tap a gear icon or profile avatar)
    // await tester.tap(find.byIcon(Icons.settings)); 
    // await tester.pumpAndSettle();

    // 6. Tap the Sign Out button
    // await tester.tap(find.text('Sign Out'));
    // await tester.pumpAndSettle();

    // 7. Verify we are redirected back to the LoginScreen
    // expect(find.byKey(const ValueKey('login')), findsOneWidget);
  });

  testWidgets('User can toggle between light and dark theme', (WidgetTester tester) async {
    // 1. Preset SharedPreferences to bypass onboarding
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    // 2. Start the app
    await app.launchApp(isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 3. Log in as a guest
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    // 4. Verify we bypassed onboarding and went straight to the Dashboard
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);

    // --- 🚨 ACTION REQUIRED 🚨 ---
    // Uncomment and update the finders below to match your settings and theme toggle UI:

    // 5. Navigate to settings (e.g., tap a gear icon)
    await tester.tap(find.byIcon(Icons.settings)); 
    await tester.pumpAndSettle();

    // 6. Verify we are currently in Dark Mode by checking the Scaffold background color
    var scaffold = tester.firstWidget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF051024)); // Your premium navy blue

    // 7. Tap the theme toggle button (e.g., a switch or a button labeled 'Light Mode')
    await tester.tap(find.text('Light Mode'));
    await tester.pumpAndSettle();

    // 8. Verify the theme changed to Light Mode!
    scaffold = tester.firstWidget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFF5F6F8)); // Your light mode background
  });

  testWidgets('Injecting a Mock AuthService to bypass Firebase', (WidgetTester tester) async {
    // 1. Create the mock
    final mockAuthService = MockAuthService();
    
    // 2. Setup the mock behavior to pretend no one is logged in, and do nothing on tap
    when(() => mockAuthService.authStateChanges).thenAnswer((_) => Stream.value(null));
    when(() => mockAuthService.signInAsGuest()).thenAnswer((_) async {});

    // 3. Launch the app using our new backdoor, passing in the mock!
    await app.launchApp(authService: mockAuthService, isTestEnvironment: true);
    await tester.pumpAndSettle();

    // 4. Interact with the UI
    await tester.tap(find.text('Continue as Guest'));
    await tester.pump(); // We just pump once here since we didn't mock a full user state change

    // 5. Verify the mock was called instead of the real Firebase emulator!
    verify(() => mockAuthService.signInAsGuest()).called(1);
  });

  testWidgets('Non-pro user is shown paywall when accessing a pro feature', (WidgetTester tester) async {
    // 1. SETUP: Launch the app as a logged-in, non-pro user who has seen onboarding.
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'last_seen_version': app.globalAppVersion, // Use the real global version to bypass "What's New"
    });
    final mockAuthService = MockAuthService();
    final mockUser = MockUser();
    when(() => mockAuthService.authStateChanges).thenAnswer((_) => Stream.value(mockUser));

    // 2. Launch the app with our test flags
    await app.launchApp(
      authService: mockAuthService,
      isTestEnvironment: true,
      isProUserChecker: () async => false, // IMPORTANT: Simulate a non-pro user
    );
    await tester.pumpAndSettle();

    // 3. VERIFY we are on the dashboard
    expect(find.byKey(const ValueKey('dashboard')), findsOneWidget);

    // 4. ACTION: Tap on a pro-only feature.
    //    🚨 You will need to replace this with a real finder for a pro feature in your UI.
    // await tester.tap(find.text('Pro Journey'));
    // await tester.pumpAndSettle();

    // 5. VERIFY: The paywall is shown.
    //    🚨 You will need to replace this with a real finder for your paywall screen.
    // expect(find.text('Upgrade to Orbit Pro'), findsOneWidget);
  });
}