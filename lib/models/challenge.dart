import 'package:cloud_firestore/cloud_firestore.dart';

/// A time-boxed shared commitment among mutual friends (7/14/30 days) --
/// created via the createChallenge Cloud Function (needs to verify every
/// invitee is a mutual friend of the creator, which firestore.rules can't
/// cheaply check across two different users' documents). Lives as a
/// top-level `challenges/{id}` collection since it's genuinely shared
/// across multiple UIDs, not owned by one user.
class GroupChallenge {
  final String id;
  final String creatorId;
  final String title;
  final String goal;
  final List<String> participantIds;
  final DateTime startDate;
  final DateTime endDate;

  GroupChallenge({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.goal,
    required this.participantIds,
    required this.startDate,
    required this.endDate,
  });

  bool get isActive => DateTime.now().isBefore(endDate);

  int get totalDays => endDate.difference(startDate).inDays;

  factory GroupChallenge.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GroupChallenge(
      id: doc.id,
      creatorId: data['creatorId']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Challenge',
      goal: data['goal']?.toString() ?? '',
      participantIds: data['participantIds'] is List
          ? List<String>.from(data['participantIds'])
          : [],
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// One participant's own check-in record within a [GroupChallenge] -- lives
/// at challenges/{id}/progress/{uid}. Only the owning participant can write
/// it; any participant of the parent challenge can read anyone's, which is
/// what powers the shared leaderboard.
class ChallengeProgress {
  final String userId;
  final Map<String, bool> checkins;

  ChallengeProgress({required this.userId, required this.checkins});

  int get checkinCount => checkins.values.where((v) => v).length;

  bool isCheckedInOn(DateTime date) {
    final key = date.toIso8601String().substring(0, 10);
    return checkins[key] == true;
  }

  factory ChallengeProgress.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChallengeProgress(
      userId: doc.id,
      checkins: data['checkins'] is Map
          ? Map<String, bool>.from(
              (data['checkins'] as Map).map(
                (k, v) => MapEntry(k.toString(), v == true),
              ),
            )
          : {},
    );
  }
}
