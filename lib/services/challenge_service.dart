import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';

/// Group Challenges: creation goes through the createChallenge Cloud
/// Function (needs to verify every invitee is a mutual friend, which
/// firestore.rules can't cheaply check -- see firestore.rules' comment on
/// the challenges collection). Daily check-ins are direct, rules-validated
/// Firestore writes to the user's own progress doc, matching how every
/// other single-doc, same-user mutation in this app works.
class ChallengeService {
  static final _db = FirebaseFirestore.instance;

  /// Returns null on success, or a user-facing error message.
  static Future<String?> createChallenge({
    required String title,
    required String goal,
    required int durationDays,
    required List<String> inviteeUids,
  }) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('createChallenge').call({
        'title': title,
        'goal': goal,
        'durationDays': durationDays,
        'inviteeUids': inviteeUids,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not create the challenge.';
    } catch (e) {
      return 'Could not create the challenge. Please try again.';
    }
  }

  /// Every challenge the current user is a participant in, newest first.
  static Stream<List<GroupChallenge>> myChallenges() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('challenges')
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(GroupChallenge.fromSnapshot).toList(),
        );
  }

  /// Every participant's check-in record for [challengeId] -- powers the
  /// shared leaderboard. Readable by any participant per firestore.rules.
  static Stream<List<ChallengeProgress>> progressFor(String challengeId) {
    return _db
        .collection('challenges')
        .doc(challengeId)
        .collection('progress')
        .snapshots()
        .map(
          (snap) => snap.docs.map(ChallengeProgress.fromSnapshot).toList(),
        );
  }

  /// Toggles today's check-in for the current user within [challengeId].
  static Future<void> setTodayCheckin(String challengeId, bool checkedIn) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db
        .collection('challenges')
        .doc(challengeId)
        .collection('progress')
        .doc(uid)
        .set({
          'checkins': {today: checkedIn},
        }, SetOptions(merge: true));
  }
}
