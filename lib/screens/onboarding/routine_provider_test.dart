import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orbit/providers/routine_provider.dart';
import 'package:fake_async/fake_async.dart';

// Mocks
class MockAudioPlayer extends Mock implements AudioPlayer {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// Fallback Values
class FakeAssetSource extends Fake implements AssetSource {}

void main() {
  late RoutineProvider routineProvider;
  late MockAudioPlayer mockAudioPlayer;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockFirebaseFirestore mockFirebaseFirestore;
  late MockUser mockUser;
  late StreamController<User?> authStateController;

  setUpAll(() {
    registerFallbackValue(FakeAssetSource());
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();
    mockFirebaseAuth = MockFirebaseAuth();
    mockFirebaseFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    authStateController = StreamController<User?>();

    // Mock dependencies for initialization
    when(() => mockFirebaseAuth.authStateChanges()).thenAnswer((_) => authStateController.stream);
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test_user');

    // Mock Firestore for _loadData to prevent network errors
    final mockDocRef = MockDocumentReference();
    final mockCollectionRef = MockCollectionReference();
    final mockDocSnapshot = MockDocumentSnapshot();
    when(() => mockFirebaseFirestore.collection('users')).thenReturn(mockCollectionRef);
    when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
    when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
    when(() => mockDocSnapshot.exists).thenReturn(false); // Simplest case: no cloud data
    when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});

    // Mock AudioPlayer behavior
    when(() => mockAudioPlayer.play(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    authStateController.close();
    routineProvider.dispose();
  });

  group('toggleHabit', () {
    test('plays sound when a habit is completed and sounds are enabled', () {
      fakeAsync((async) {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'sounds': true,
          'last_reset_date': DateTime.now().toIso8601String().substring(0, 10),
        });

        routineProvider = RoutineProvider(
          audioPlayer: mockAudioPlayer,
          auth: mockFirebaseAuth,
          db: mockFirebaseFirestore,
        );

        // Trigger _loadData by simulating login and wait for it to complete
        authStateController.add(mockUser);
        async.flushMicrotasks();

        // Act
        routineProvider.toggleHabit('Drink Water');
        async.flushMicrotasks();

        // Assert
        verify(() => mockAudioPlayer.play(AssetSource('audio/success_chime.mp3'))).called(1);
      });
    });

    test('does NOT play sound when sounds are disabled', () {
      fakeAsync((async) {
        // Arrange
        SharedPreferences.setMockInitialValues({'sounds': false});

        routineProvider = RoutineProvider(
          audioPlayer: mockAudioPlayer,
          auth: mockFirebaseAuth,
          db: mockFirebaseFirestore,
        );

        authStateController.add(mockUser);
        async.flushMicrotasks();

        // Act
        routineProvider.toggleHabit('Drink Water');
        async.flushMicrotasks();

        // Assert
        verifyNever(() => mockAudioPlayer.play(any()));
      });
    });
  });
}