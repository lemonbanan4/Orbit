import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- HABITS ---

  Stream<QuerySnapshot> getUserHabits(String userId) {
    return _db.collection('habits').where('uid', isEqualTo: userId).snapshots();
  }

  Future<DocumentReference> createHabit(Map<String, dynamic> habitData) {
    return _db.collection('habits').add(habitData);
  }

  Future<void> updateHabit(String habitId, Map<String, dynamic> data) {
    return _db.collection('habits').doc(habitId).update(data);
  }

  Future<void> deleteHabit(String habitId) {
    return _db.collection('habits').doc(habitId).delete();
  }

  // --- ROUTINES ---

  Stream<QuerySnapshot> getUserRoutines(String userId) {
    return _db.collection('routines').where('uid', isEqualTo: userId).snapshots();
  }

  Future<DocumentReference> createRoutine(Map<String, dynamic> routineData) {
    return _db.collection('routines').add(routineData);
  }

  Future<void> updateRoutine(String routineId, Map<String, dynamic> data) {
    return _db.collection('routines').doc(routineId).update(data);
  }

  Future<void> deleteRoutine(String routineId) {
    return _db.collection('routines').doc(routineId).delete();
  }
}