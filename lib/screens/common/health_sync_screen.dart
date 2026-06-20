// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// // Note: You need to add the 'health' package to your pubspec.yaml for this to work.
// import 'package:health/health.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class HealthSyncScreen extends StatefulWidget {
//   const HealthSyncScreen({super.key});

//   @override
//   State<HealthSyncScreen> createState() => _HealthSyncScreenState();
// }

// class _HealthSyncScreenState extends State<HealthSyncScreen> {
//   bool _isAuthorized = false;
//   bool _isLoading = true;
//   String _syncStatus = 'Not synced yet.';

//   // Define the data types you want to read
//   static const List<HealthDataType> types = [
//     HealthDataType.WORKOUT,
//     HealthDataType.STEPS,
//     HealthDataType.ACTIVE_ENERGY_BURNED,
//   ];

//   // Define the permissions for those data types
//   final List<HealthDataAccess> permissions = [
//     HealthDataAccess.READ,
//     HealthDataAccess.READ,
//     HealthDataAccess.READ,
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _checkAuthStatus();
//   }

//   Future<void> _checkAuthStatus() async {
//     final health = Health();
//     bool? isAuthorized =
//         await health.hasPermissions(types, permissions: permissions);
//     setState(() {
//       _isAuthorized = isAuthorized ?? false;
//       _isLoading = false;
//     });
//   }

//   Future<void> _requestAuthorization() async {
//     setState(() => _isLoading = true);
//     final health = Health();
//     bool? authorized =
//         await health.requestAuthorization(types, permissions: permissions);

//     setState(() {
//       _isAuthorized = authorized ?? false;
//       _isLoading = false;
//     });
//   }

//   Future<void> _syncHealthData() async {
//     if (!_isAuthorized) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please authorize first.')),
//       );
//       return;
//     }

//     setState(() => _syncStatus = 'Syncing...');
//     HapticFeedback.lightImpact();

//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       setState(() => _syncStatus = 'Error: Not logged in.');
//       return;
//     }

//     // Prevent XP farming by only allowing one sync per day
//     final userDoc = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .get();
//     final lastSyncTimestamp = userDoc.data()?['last_health_sync'] as Timestamp?;
//     if (lastSyncTimestamp != null) {
//       final lastSyncDate = lastSyncTimestamp.toDate();
//       final now = DateTime.now();
//       if (lastSyncDate.year == now.year &&
//           lastSyncDate.month == now.month &&
//           lastSyncDate.day == now.day) {
//         setState(
//             () => _syncStatus = 'Already synced today. Try again tomorrow!');
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//             content: Text('You can only sync once per day.'),
//             backgroundColor: Colors.orangeAccent));
//         return;
//       }
//     }

//     final health = Health();
//     final now = DateTime.now();
//     final yesterday = now.subtract(const Duration(days: 1));

//     try {
//       List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
//         startTime: yesterday,
//         endTime: now,
//         types: types,
//       );

//       int workoutCount =
//           healthData.where((p) => p.type == HealthDataType.WORKOUT).length;

//       double totalSteps = 0;
//       for (var p in healthData.where((p) => p.type == HealthDataType.STEPS)) {
//         try {
//           totalSteps += ((p.value as dynamic).numericValue as num).toDouble();
//         } catch (_) {
//           totalSteps += double.tryParse(p.value.toString()) ?? 0.0;
//         }
//       }

//       double totalCalories = 0;
//       for (var p in healthData
//           .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)) {
//         try {
//           totalCalories +=
//               ((p.value as dynamic).numericValue as num).toDouble();
//         } catch (_) {
//           totalCalories += double.tryParse(p.value.toString()) ?? 0.0;
//         }
//       }

//       int xpEarned = 0;

//       if (workoutCount > 0) xpEarned += 50; // 50 XP for any workout
//       if (totalSteps >= 10000) xpEarned += 25; // 25 XP for 10k steps
//       xpEarned +=
//           (totalCalories / 100).floor() * 5; // 5 XP for every 100 calories

//       if (xpEarned > 0) {
//         try {
//           await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .set({
//             'xp': FieldValue.increment(xpEarned),
//             'last_health_sync': FieldValue.serverTimestamp(),
//           }, SetOptions(merge: true));

//           // --- NEW: Auto-progress the Health path! ---
//           final interests = (userDoc.data()?['interests'] as List<dynamic>?)
//                   ?.cast<String>() ??
//               [];
//           final dateStr =
//               '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

//           if (!interests.contains('Health')) {
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .update({
//               'interests': FieldValue.arrayUnion(['Health'])
//             });
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .collection('habits')
//                 .doc('health')
//                 .set({
//               'path': 'Health',
//               'completedDays': 1,
//               'totalDays': 7,
//               'icon': 'Fitness',
//               'color': Colors.redAccent.toARGB32(),
//               'last_completed': FieldValue.serverTimestamp(),
//               'completedDates': FieldValue.arrayUnion([dateStr]),
//             }, SetOptions(merge: true));
//           } else {
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .collection('habits')
//                 .doc('health')
//                 .set({
//               'completedDays': FieldValue.increment(1),
//               'last_completed': FieldValue.serverTimestamp(),
//               'completedDates': FieldValue.arrayUnion([dateStr]),
//             }, SetOptions(merge: true));
//           }
//         } catch (e) {
//           debugPrint('Failed to sync XP & Health Path: $e');
//         }
//       }

//       setState(() {
//         _syncStatus =
//             'Last synced: ${DateTime.now().toLocal()}.\nFound $workoutCount workouts, ${totalSteps.toInt()} steps, and ${totalCalories.toInt()} calories.\nEarned $xpEarned XP!';
//       });

//       if (!context.mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('Health data synced!'),
//             backgroundColor: Colors.green),
//       );
//     } catch (e) {
//       setState(() => _syncStatus = 'Error syncing: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Health Sync'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   const Icon(Icons.monitor_heart_rounded,
//                       size: 80, color: Colors.redAccent),
//                   const SizedBox(height: 24),
//                   const Text(
//                     'Automate Your Habits',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Connect to Apple Health or Google Fit to automatically complete habits like "Workout" or "Go for a walk" when you record them on your device.',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                         color: Colors.grey, fontSize: 16, height: 1.5),
//                   ),
//                   const Spacer(),
//                   if (_isAuthorized)
//                     Text(_syncStatus,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(color: Colors.grey)),
//                   const SizedBox(height: 16),
//                   ElevatedButton.icon(
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       backgroundColor: _isAuthorized
//                           ? Colors.green
//                           : const Color(0xFF1A1F36),
//                       foregroundColor: Colors.white,
//                     ),
//                     onPressed:
//                         _isAuthorized ? _syncHealthData : _requestAuthorization,
//                     icon: Icon(_isAuthorized
//                         ? Icons.sync_rounded
//                         : Icons.check_circle_outline_rounded),
//                     label: Text(
//                         _isAuthorized ? 'Sync Now' : 'Connect to Health',
//                         style: const TextStyle(fontSize: 18)),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }
