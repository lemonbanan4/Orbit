import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:orbit/providers/auth_provider.dart';
import 'package:orbit/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthService mockAuthService;
  late StreamController<User?> authStateController;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Intercept Firebase Crashlytics platform channel calls so they don't crash our unit tests
    const channel = MethodChannel('plugins.flutter.io/firebase_crashlytics');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (message) async => null);
  });

  setUp(() {
    mockAuthService = MockAuthService();
    authStateController = StreamController<User?>();
    
    // Mock the authState stream so we can control when "users" log in or out
    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  test('AppAuthProvider updates user and calls notifyListeners on auth state change', () async {
    // Arrange
    final provider = AppAuthProvider(authService: mockAuthService);
    
    int listenerCallCount = 0;
    provider.addListener(() {
      listenerCallCount++;
    });

    // Assert initial state
    expect(provider.user, isNull);
    expect(listenerCallCount, 0);

    // Act 1: Simulate a user logging in
    final mockUser = MockUser();
    when(() => mockUser.uid).thenReturn('user123');
    when(() => mockUser.isAnonymous).thenReturn(false);
    
    authStateController.add(mockUser);
    await Future.delayed(Duration.zero); // Allow the stream event to process

    // Assert 1
    expect(provider.user, mockUser);
    expect(listenerCallCount, 1);

    // Act 2: Simulate a user logging out
    authStateController.add(null);
    await Future.delayed(Duration.zero);

    // Assert 2
    expect(provider.user, isNull);
    expect(listenerCallCount, 2);
  });
}