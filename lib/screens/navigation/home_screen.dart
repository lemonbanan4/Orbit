// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'package:provider/provider.dart';
// import '../../providers/routine_provider.dart';
// import '../habits/path_detail_screen.dart';
// import 'profile_screen.dart';
// import '../paywall/premium_checker.dart';
// import '../../widgets/common/premium_glass_card.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../settings/notifications_screen.dart';
// import '../../widgets/common/focus_chip.dart';
// import '../../widgets/common/journey_card.dart';
// import '../../widgets/common/current_goal_input.dart';
// import '../../widgets/common/base_orbit_screen.dart';
// import '../../widgets/habits/create_habit_sheet.dart';
// import '../onboarding/login_screen.dart';
// import '../../widgets/ai_coach_card.dart';
// import '../../services/ai_coach_service.dart';
// import '../../theme/orbit_colors.dart';
// import '../journey/journey_screen.dart';
// import '../../widgets/whats_new_popup.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   final ScrollController _scrollController = ScrollController();
//   String _fairyMessage =
//       "Commander, your orbit awaits. Tap the refresh icon to consult the stars.";
//   bool _isFairyLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _checkWhatsNew());
//   }

//   Future<void> _checkWhatsNew() async {
//     try {
//       final packageInfo = await PackageInfo.fromPlatform();
//       final currentVersion = packageInfo.version;
//       final prefs = await SharedPreferences.getInstance();
//       final lastSeenVersion = prefs.getString('last_seen_version');

//       if (lastSeenVersion != null &&
//           lastSeenVersion != currentVersion &&
//           mounted) {
//         showDialog(
//           context: context,
//           builder: (context) => const WhatsNewPopup(),
//         );
//       }
//       await prefs.setString('last_seen_version', currentVersion);
//     } catch (e) {
//       debugPrint('Error checking version: $e');
//     }
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   IconData _getIconForPath(String title) {
//     final titleLower = title.toLowerCase();
//     if (titleLower.contains('morning') || titleLower.contains('sun')) {
//       return Icons.wb_sunny_rounded;
//     }
//     if (titleLower.contains('sleep') || titleLower.contains('night')) {
//       return Icons.nightlight_round;
//     }
//     if (titleLower.contains('meditat') || titleLower.contains('mind')) {
//       return Icons.self_improvement_rounded;
//     }
//     if (titleLower.contains('workout') || titleLower.contains('fit')) {
//       return Icons.fitness_center_rounded;
//     }
//     if (titleLower.contains('read') || titleLower.contains('book')) {
//       return Icons.menu_book_rounded;
//     }
//     return Icons.explore_rounded;
//   }

//   Future<void> _refreshFairyMessage() async {
//     if (_isFairyLoading) return; // Prevent spam tapping!

//     HapticFeedback.mediumImpact();
//     setState(() {
//       _isFairyLoading = true;
//       _fairyMessage = "✨ Consulting the cosmos...";
//     });

//     // Call the new Gemini method
//     final newMessage = await AiCoachService.generateGreeting();

//     if (mounted) {
//       setState(() {
//         _fairyMessage = newMessage;
//         _isFairyLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     final String displayName = user?.displayName ?? 'Astronaut';
//     final routineProvider = context.watch<RoutineProvider>();
//     final bool isDark = routineProvider.themeMode == 'Dark' ||
//         routineProvider.themeMode == 'System';

//     // Dynamic Theme
//     final theme = Theme.of(context);
//     final Color orbColor1 =
//         isDark ? const Color(0xFF00E5FF) : const Color(0xFF00B8D4);
//     final Color textColor = theme.colorScheme.onSurface;

//     // Extension for colors
//     final orbitColors = Theme.of(context).extension<OrbitColors>();

//     return BaseOrbitScreen(
//       title: 'Orbit',
//       actions: [
//         IconButton(
//           icon: Icon(Icons.person_outline_rounded, color: textColor),
//           onPressed: () {
//             HapticFeedback.selectionClick();
//             Navigator.push(context,
//                 MaterialPageRoute(builder: (_) => const ProfileScreen()));
//           },
//         ),
//         const SizedBox(width: 16),
//       ],
//       floatingActionButton: AnimatedContainer(
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOutCubic,
//         margin: EdgeInsets.only(
//           bottom: 0.0,
//         ),
//         child: FloatingActionButton.extended(
//           onPressed: () {
//             HapticFeedback.lightImpact();
//             CreateHabitSheet.show(context);
//           },
//           backgroundColor: const Color(0xFF00E5FF),
//           foregroundColor: Colors.black,
//           icon: const Icon(Icons.add_rounded, size: 24),
//           label: const Text(
//             'New Habit',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           elevation: 8,
//         ),
//       ),
//       body: Stack(
//         children: [
//           // THE PARALLAX BACKGROUND LAYER
//           AnimatedBuilder(
//             animation: _scrollController,
//             builder: (context, child) {
//               // Calculate the parallax offset
//               double parallaxOffset =
//                   0.0; // Removed 'final' so it can dynamically update!
//               if (_scrollController.hasClients) {
//                 parallaxOffset = _scrollController.offset * -0.1;
//               }
//               return Positioned(
//                 top: -50 + parallaxOffset,
//                 left: -10,
//                 right: -10,
//                 bottom: -50,
//                 child: Opacity(
//                   opacity: isDark ? 0.4 : 0.1,
//                   child: Image.asset(
//                     'assets/images/nebula_bg.png',
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               );
//             },
//           ),
//           user == null
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.account_circle_rounded,
//                         size: 80,
//                         color: orbColor1.withOpacity(0.5),
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         'Not Logged In',
//                         style: TextStyle(
//                           color: textColor,
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Please restart the app or sign in again.',
//                         style: TextStyle(color: textColor.withOpacity(0.6)),
//                       ),
//                       const SizedBox(height: 24),
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           HapticFeedback.lightImpact();
//                           Navigator.pushReplacement(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => const LoginScreen(),
//                             ),
//                           );
//                         },
//                         icon: const Icon(Icons.login_rounded),
//                         label: const Text('Go to Login'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: orbColor1,
//                           foregroundColor: Colors.black,
//                         ),
//                       ),
//                     ],
//                   ),
//                 )
//               : StreamBuilder<DocumentSnapshot>(
//                   stream: FirebaseFirestore.instance
//                       .collection('users')
//                       .doc(user.uid)
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting &&
//                         !snapshot.hasData) {
//                       return Center(
//                         child: CircularProgressIndicator(color: orbColor1),
//                       );
//                     }

//                     final data = snapshot.data?.data() as Map<String, dynamic>?;
//                     final interests = (data?['interests'] as List<dynamic>?)
//                             ?.cast<String>() ??
//                         [];
//                     final streakCount = data?['streakCount'] as int? ?? 0;

//                     final confettiEnabled = routineProvider.confettiEnabled;

//                     return RefreshIndicator(
//                       color: orbColor1,
//                       backgroundColor:
//                           isDark ? const Color(0xFF1A1F36) : Colors.white,
//                       onRefresh: () async {
//                         HapticFeedback.lightImpact();
//                         await FirebaseFirestore.instance
//                             .collection('users')
//                             .doc(user.uid)
//                             .get(const GetOptions(source: Source.server));
//                       },
//                       child: CustomScrollView(
//                         controller: _scrollController,
//                         physics: const BouncingScrollPhysics(
//                           parent: AlwaysScrollableScrollPhysics(),
//                         ),
//                         slivers: [
//                           SliverPadding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 24,
//                               vertical: 24,
//                             ),
//                             sliver: SliverList(
//                               delegate: SliverChildListDelegate([
//                                 // --- HEADER: WELCOME & STREAK ---
//                                 Row(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             'Welcome back,',
//                                             style: TextStyle(
//                                               color: textColor.withOpacity(0.6),
//                                               fontSize: 16,
//                                               letterSpacing: 1.0,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             '$displayName!',
//                                             style: TextStyle(
//                                               color: textColor,
//                                               fontSize: 28,
//                                               fontWeight: FontWeight.w900,
//                                               letterSpacing: -0.5,
//                                             ),
//                                           )
//                                               .animate()
//                                               .fadeIn(duration: 600.ms)
//                                               .slideX(
//                                                 begin: -0.1,
//                                                 curve: Curves.easeOutCubic,
//                                               ),
//                                         ],
//                                       ),
//                                     ),
//                                     Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         StreamBuilder<QuerySnapshot>(
//                                           stream: FirebaseFirestore.instance
//                                               .collection('users')
//                                               .doc(user.uid)
//                                               .collection('notifications')
//                                               .snapshots(),
//                                           builder: (context, notifSnap) {
//                                             int unreadCount = 0;
//                                             if (notifSnap.hasData) {
//                                               unreadCount = notifSnap.data!.docs
//                                                   .where((doc) {
//                                                 final data = doc.data()
//                                                     as Map<String, dynamic>;
//                                                 return data['isArchived'] !=
//                                                     true;
//                                               }).length;
//                                             }
//                                             return GestureDetector(
//                                               onTap: () {
//                                                 HapticFeedback.lightImpact();
//                                                 Navigator.push(
//                                                   context,
//                                                   MaterialPageRoute(
//                                                     builder: (context) =>
//                                                         const NotificationsScreen(),
//                                                   ),
//                                                 );
//                                               },
//                                               child: Stack(
//                                                 clipBehavior: Clip.none,
//                                                 children: [
//                                                   Container(
//                                                     padding:
//                                                         const EdgeInsets.all(
//                                                       12,
//                                                     ),
//                                                     decoration: BoxDecoration(
//                                                       color: textColor
//                                                           .withOpacity(0.05),
//                                                       shape: BoxShape.circle,
//                                                       border: Border.all(
//                                                         color: textColor
//                                                             .withOpacity(0.1),
//                                                       ),
//                                                     ),
//                                                     child: Icon(
//                                                       Icons
//                                                           .notifications_none_rounded,
//                                                       color: textColor,
//                                                       size: 24,
//                                                     ),
//                                                   ),
//                                                   if (unreadCount > 0)
//                                                     Positioned(
//                                                       top: -4,
//                                                       right: -4,
//                                                       child: Container(
//                                                         padding:
//                                                             const EdgeInsets
//                                                                 .all(
//                                                           6,
//                                                         ),
//                                                         decoration:
//                                                             const BoxDecoration(
//                                                           color:
//                                                               Colors.redAccent,
//                                                           shape:
//                                                               BoxShape.circle,
//                                                         ),
//                                                         child: Text(
//                                                           unreadCount > 9
//                                                               ? '9+'
//                                                               : unreadCount
//                                                                   .toString(),
//                                                           style:
//                                                               const TextStyle(
//                                                             color: Colors.white,
//                                                             fontSize: 10,
//                                                             fontWeight:
//                                                                 FontWeight.bold,
//                                                           ),
//                                                         ),
//                                                       ).animate().scaleXY(
//                                                             begin: 0,
//                                                             end: 1,
//                                                             curve: Curves
//                                                                 .easeOutBack,
//                                                           ),
//                                                     ),
//                                                 ],
//                                               ),
//                                             );
//                                           },
//                                         ),
//                                         const SizedBox(width: 12),
//                                         Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.end,
//                                           children: [
//                                             if (streakCount > 0)
//                                               Builder(
//                                                 builder: (context) {
//                                                   final isFrozen =
//                                                       data?['isStreakFrozen'] ==
//                                                           true;
//                                                   final streakColor = isFrozen
//                                                       ? Colors.cyanAccent
//                                                       : Colors.orangeAccent;
//                                                   final streakIcon = isFrozen
//                                                       ? Icons.ac_unit_rounded
//                                                       : Icons
//                                                           .local_fire_department_rounded;
//                                                   return Stack(
//                                                     alignment: Alignment.center,
//                                                     clipBehavior: Clip.none,
//                                                     children: [
//                                                       PremiumGlassCard(
//                                                         padding:
//                                                             const EdgeInsets
//                                                                 .symmetric(
//                                                           horizontal: 16,
//                                                           vertical: 12,
//                                                         ),
//                                                         child: Row(
//                                                           mainAxisSize:
//                                                               MainAxisSize.min,
//                                                           children: [
//                                                             Icon(
//                                                               streakIcon,
//                                                               color:
//                                                                   streakColor,
//                                                               size: 24,
//                                                             )
//                                                                 .animate(
//                                                                   onPlay: (c) =>
//                                                                       c.repeat(
//                                                                     reverse:
//                                                                         true,
//                                                                   ),
//                                                                 )
//                                                                 .scaleXY(
//                                                                   begin: 0.9,
//                                                                   end: 1.1,
//                                                                   duration:
//                                                                       1.seconds,
//                                                                 ),
//                                                             const SizedBox(
//                                                               width: 8,
//                                                             ),
//                                                             Text(
//                                                               '$streakCount',
//                                                               style: TextStyle(
//                                                                 color:
//                                                                     streakColor,
//                                                                 fontWeight:
//                                                                     FontWeight
//                                                                         .bold,
//                                                                 fontSize: 18,
//                                                               ),
//                                                             ),
//                                                           ],
//                                                         ),
//                                                       )
//                                                           .animate()
//                                                           .fade(
//                                                             duration: 800.ms,
//                                                           )
//                                                           .scaleXY(
//                                                             begin: 0.8,
//                                                             end: 1.0,
//                                                             curve: Curves
//                                                                 .easeOutBack,
//                                                           ),
//                                                     ],
//                                                   );
//                                                 },
//                                               ),
//                                             if ((data?['streakFreezes']
//                                                         as int? ??
//                                                     0) >
//                                                 0) ...[
//                                               if (streakCount > 0)
//                                                 const SizedBox(height: 8),
//                                               PremiumGlassCard(
//                                                 padding:
//                                                     const EdgeInsets.symmetric(
//                                                   horizontal: 12,
//                                                   vertical: 8,
//                                                 ),
//                                                 child: Row(
//                                                   mainAxisSize:
//                                                       MainAxisSize.min,
//                                                   children: [
//                                                     const Icon(
//                                                       Icons.ac_unit_rounded,
//                                                       color: Colors.blueAccent,
//                                                       size: 16,
//                                                     )
//                                                         .animate(
//                                                           onPlay: (c) =>
//                                                               c.repeat(
//                                                             reverse: true,
//                                                           ),
//                                                         )
//                                                         .shimmer(
//                                                           duration: 2.seconds,
//                                                         ),
//                                                     const SizedBox(
//                                                       width: 6,
//                                                     ),
//                                                     const Text(
//                                                       'Freeze Active',
//                                                       style: TextStyle(
//                                                         color:
//                                                             Colors.blueAccent,
//                                                         fontWeight:
//                                                             FontWeight.bold,
//                                                         fontSize: 12,
//                                                       ),
//                                                     ),
//                                                   ],
//                                                 ),
//                                               )
//                                                   .animate()
//                                                   .fade(duration: 800.ms)
//                                                   .scaleXY(
//                                                     begin: 0.8,
//                                                     end: 1.0,
//                                                     curve: Curves.easeOutBack,
//                                                   ),
//                                             ],
//                                           ],
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),

//                                 const SizedBox(height: 24),
//                                 CurrentGoalInput(
//                                   initialGoal:
//                                       data?['currentGoal'] as String? ?? '',
//                                   uid: user.uid,
//                                 ),

//                                 const SizedBox(height: 40),

//                                 // --- THE GLOBAL JOURNEY & AI FAIRY ---
//                                 AICoachCard(
//                                   fairyMessage: _fairyMessage,
//                                   onRefresh: () {
//                                     _refreshFairyMessage();
//                                   },
//                                 )
//                                     .animate()
//                                     .fade(delay: 150.ms)
//                                     .slideY(begin: 0.2),

//                                 const SizedBox(height: 40),

//                                 // --- FOCUS AREAS ---
//                                 Text(
//                                   'Your Focus Areas',
//                                   style: TextStyle(
//                                     color: textColor.withOpacity(0.9),
//                                     fontSize: 20,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 )
//                                     .animate()
//                                     .fade(delay: 100.ms)
//                                     .slideY(begin: 0.2),
//                                 const SizedBox(height: 16),
//                                 Wrap(
//                                   spacing: 10.0,
//                                   runSpacing: 10.0,
//                                   crossAxisAlignment: WrapCrossAlignment.center,
//                                   children: [
//                                     ...interests.map(
//                                       (interest) => FocusChip(
//                                         label: interest,
//                                         onDeleted: () => _removeInterest(
//                                           user.uid,
//                                           interest,
//                                           interests,
//                                         ),
//                                       ),
//                                     ),
//                                     if (interests.length < 5) ...[
//                                       // --- COACH MARK TUTORIAL ---
//                                       if (interests.isEmpty)
//                                         Container(
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 12,
//                                             vertical: 8,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: const Color(
//                                               0xFF00E5FF,
//                                             ),
//                                             borderRadius:
//                                                 BorderRadius.circular(12),
//                                           ),
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: const [
//                                               Text(
//                                                 'Start here!',
//                                                 style: TextStyle(
//                                                   color: Colors.black87,
//                                                   fontWeight: FontWeight.bold,
//                                                   fontSize: 12,
//                                                 ),
//                                               ),
//                                               SizedBox(width: 4),
//                                               Icon(
//                                                 Icons.arrow_forward_rounded,
//                                                 color: Colors.black87,
//                                                 size: 16,
//                                               ),
//                                             ],
//                                           ),
//                                         )
//                                             .animate(
//                                               onPlay: (c) =>
//                                                   c.repeat(reverse: true),
//                                             )
//                                             .moveX(begin: 0, end: 5),

//                                       ActionChip(
//                                         label: const Icon(
//                                           Icons.add_rounded,
//                                           size: 20,
//                                           color: Colors.white,
//                                         ),
//                                         backgroundColor:
//                                             Colors.white.withOpacity(0.1),
//                                         side: BorderSide(
//                                           color: Colors.white.withOpacity(0.3),
//                                         ),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius: BorderRadius.circular(
//                                             20,
//                                           ),
//                                         ),
//                                         onPressed: () {
//                                           HapticFeedback.lightImpact();
//                                           if (interests.isNotEmpty) {
//                                             PremiumChecker.requirePro(
//                                               context,
//                                               onAccessGranted: () {
//                                                 _showAddInterestSheet(
//                                                   context,
//                                                   user.uid,
//                                                 );
//                                               },
//                                             );
//                                           } else {
//                                             _showAddInterestSheet(
//                                               context,
//                                               user.uid,
//                                             );
//                                           }
//                                         },
//                                       ),
//                                     ],
//                                   ],
//                                 ).animate().fade(delay: 200.ms),

//                                 const SizedBox(height: 48),

//                                 // --- ACTIVE PATHS / JOURNEY ---
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       'Active Journeys',
//                                       style: TextStyle(
//                                         color: textColor.withOpacity(0.9),
//                                         fontSize: 20,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                                     TextButton.icon(
//                                       onPressed: () {
//                                         HapticFeedback.lightImpact();
//                                         Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                               builder: (context) =>
//                                                   const JourneyScreen()),
//                                         );
//                                       },
//                                       icon: const Icon(Icons.map_rounded,
//                                           size: 16),
//                                       label: const Text('Roadmap'),
//                                       style: TextButton.styleFrom(
//                                         foregroundColor:
//                                             const Color(0xFF00E5FF),
//                                       ),
//                                     ),
//                                   ],
//                                 )
//                                     .animate()
//                                     .fade(delay: 300.ms)
//                                     .slideY(begin: 0.2),
//                                 const SizedBox(height: 16),

//                                 if (interests.isEmpty)
//                                   Text(
//                                     'Add a focus area above to begin your journey.',
//                                     style: TextStyle(
//                                       color: textColor.withOpacity(0.5),
//                                     ),
//                                   ),

//                                 StreamBuilder<QuerySnapshot>(
//                                   stream: FirebaseFirestore.instance
//                                       .collection('users')
//                                       .doc(user.uid)
//                                       .collection('habits')
//                                       .snapshots(),
//                                   builder: (context, habitSnap) {
//                                     if (!habitSnap.hasData) {
//                                       return const SizedBox.shrink();
//                                     }
//                                     final habitsDocs = habitSnap.data!.docs;

//                                     return Column(
//                                       children: interests.map((title) {
//                                         final matches = habitsDocs
//                                             .where(
//                                               (doc) =>
//                                                   (doc.data() as Map)['path'] ==
//                                                   title,
//                                             )
//                                             .toList();

//                                         int completed = 0;
//                                         int total = 7;
//                                         int colorValue =
//                                             0xFF00E5FF; // Default Cyan
//                                         String? customIcon;

//                                         if (matches.isNotEmpty) {
//                                           final data = matches.first.data()
//                                               as Map<String, dynamic>;
//                                           completed =
//                                               data['completedDays'] as int? ??
//                                                   0;
//                                           total =
//                                               data['totalDays'] as int? ?? 7;
//                                           colorValue = data['color'] as int? ??
//                                               0xFF00E5FF;
//                                           customIcon = data['icon'] as String?;
//                                         }

//                                         double progress = total > 0
//                                             ? (completed / total).clamp(
//                                                 0.0,
//                                                 1.0,
//                                               )
//                                             : 0.0;

//                                         IconData iconToUse = _getIconForPath(
//                                           title,
//                                         );
//                                         if (customIcon != null) {
//                                           final Map<String, IconData>
//                                               availableIcons = {
//                                             'Explore': Icons.explore_rounded,
//                                             'Fitness':
//                                                 Icons.fitness_center_rounded,
//                                             'Book': Icons.menu_book_rounded,
//                                             'Mind':
//                                                 Icons.self_improvement_rounded,
//                                             'Sun': Icons.wb_sunny_rounded,
//                                             'Moon': Icons.nightlight_round,
//                                             'Star': Icons.star_rounded,
//                                             'Work': Icons.work_rounded,
//                                             'Heart': Icons.favorite_rounded,
//                                           };
//                                           iconToUse =
//                                               availableIcons[customIcon] ??
//                                                   iconToUse;
//                                         }

//                                         return Padding(
//                                           padding: const EdgeInsets.only(
//                                             bottom: 16.0,
//                                           ),
//                                           child: Dismissible(
//                                             key: Key('journey_$title'),
//                                             direction:
//                                                 DismissDirection.endToStart,
//                                             confirmDismiss: (direction) async {
//                                               if (interests.length <= 1) {
//                                                 ScaffoldMessenger.of(
//                                                   context,
//                                                 ).showSnackBar(
//                                                   const SnackBar(
//                                                     content: Text(
//                                                       'You must have at least one focus area.',
//                                                     ),
//                                                     backgroundColor:
//                                                         Colors.redAccent,
//                                                   ),
//                                                 );
//                                                 return false;
//                                               }
//                                               return true;
//                                             },
//                                             onDismissed: (direction) {
//                                               HapticFeedback.mediumImpact();
//                                               _removeInterest(
//                                                 user.uid,
//                                                 title,
//                                                 interests,
//                                               );
//                                             },
//                                             background: Container(
//                                               alignment: Alignment.centerRight,
//                                               padding: const EdgeInsets.only(
//                                                 right: 24,
//                                               ),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.redAccent
//                                                     .withOpacity(0.8),
//                                                 borderRadius:
//                                                     BorderRadius.circular(24),
//                                               ),
//                                               child: const Icon(
//                                                 Icons.delete_sweep_rounded,
//                                                 color: Colors.white,
//                                                 size: 32,
//                                               ),
//                                             ),
//                                             child: JourneyCard(
//                                               title: title,
//                                               subtitle:
//                                                   '$completed of $total days completed',
//                                               progress: progress,
//                                               icon: iconToUse,
//                                               accentColor: Color(colorValue),
//                                               onTap: () => _navigateToJourney(
//                                                 context,
//                                                 title,
//                                                 Color(colorValue),
//                                               ),
//                                             ),
//                                           ),
//                                         ).animate().fade().slideY(begin: 0.1);
//                                       }).toList(),
//                                     );
//                                   },
//                                 ),

//                                 const SizedBox(height: 80), // Bottom padding
//                               ]),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//         ],
//       ),
//     );
//   }

//   void _navigateToJourney(
//     BuildContext context,
//     String title,
//     Color accentColor,
//   ) {
//     HapticFeedback.selectionClick();
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => PathDetailScreen(
//           title: title,
//           subtitle: 'Journey Focus Area',
//           icon: _getIconForPath(title),
//         ),
//       ),
//     );
//   }

//   Future<void> _removeInterest(
//     String uid,
//     String interest,
//     List<String> interests,
//   ) async {
//     if (interests.length <= 1) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You must have at least one focus area.'),
//           backgroundColor: Colors.redAccent,
//         ),
//       );
//       return;
//     }
//     await FirebaseFirestore.instance.collection('users').doc(uid).update({
//       'interests': FieldValue.arrayRemove([interest]),
//     });
//   }

//   void _showAddInterestSheet(BuildContext context, String uid) {
//     int selectedDays = 7;
//     int selectedColorValue = 0xFF00E5FF;
//     final List<Color> themeColors = [
//       const Color(0xFF00E5FF), // Cyan
//       const Color(0xFF7000FF), // Purple
//       Colors.orangeAccent,
//       Colors.greenAccent,
//       Colors.pinkAccent,
//       Colors.amberAccent,
//     ];

//     String selectedIconKey = 'Explore';
//     final Map<String, IconData> availableIcons = {
//       'Explore': Icons.explore_rounded,
//       'Fitness': Icons.fitness_center_rounded,
//       'Book': Icons.menu_book_rounded,
//       'Mind': Icons.self_improvement_rounded,
//       'Sun': Icons.wb_sunny_rounded,
//       'Moon': Icons.nightlight_round,
//       'Star': Icons.star_rounded,
//       'Work': Icons.work_rounded,
//       'Heart': Icons.favorite_rounded,
//     };

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => StatefulBuilder(
//         builder: (context, setSheetState) => Padding(
//           padding: EdgeInsets.only(
//             bottom: MediaQuery.of(context).viewInsets.bottom,
//           ),
//           child: PremiumGlassCard(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   'Add Focus Area',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   autofocus: true,
//                   style: const TextStyle(color: Colors.white),
//                   decoration: InputDecoration(
//                     hintText: 'e.g. Stoicism, Reading',
//                     hintStyle: TextStyle(
//                       color: Colors.white.withOpacity(0.5),
//                     ),
//                     filled: true,
//                     fillColor: Colors.white.withOpacity(0.1),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(16),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                   onSubmitted: (val) async {
//                     if (val.trim().isNotEmpty) {
//                       await FirebaseFirestore.instance
//                           .collection('users')
//                           .doc(uid)
//                           .update({
//                         'interests': FieldValue.arrayUnion([val.trim()]),
//                       });
//                       final habitId = val.trim().toLowerCase().replaceAll(
//                             ' ',
//                             '_',
//                           );
//                       await FirebaseFirestore.instance
//                           .collection('users')
//                           .doc(uid)
//                           .collection('habits')
//                           .doc(habitId)
//                           .set({
//                         'path': val.trim(),
//                         'completedDays': 0,
//                         'totalDays': selectedDays,
//                         'color': selectedColorValue,
//                         'icon': selectedIconKey,
//                       }, SetOptions(merge: true));
//                     }
//                     if (context.mounted) Navigator.pop(context);
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Journey Duration',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [7, 21, 30].map((days) {
//                     final isSelected = selectedDays == days;
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 4.0),
//                       child: ChoiceChip(
//                         label: Text('$days Days'),
//                         selected: isSelected,
//                         selectedColor: const Color(0xFF00E5FF),
//                         backgroundColor: Colors.white.withOpacity(0.1),
//                         labelStyle: TextStyle(
//                           color: isSelected
//                               ? const Color(0xFF1A1F36)
//                               : Colors.white,
//                         ),
//                         onSelected: (selected) {
//                           if (selected) {
//                             setSheetState(() => selectedDays = days);
//                           }
//                         },
//                       ),
//                     );
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 24),
//                 const Text(
//                   'Card Theme Color',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: themeColors.map((color) {
//                     final isSelected = selectedColorValue == color.value;
//                     return GestureDetector(
//                       onTap: () {
//                         HapticFeedback.selectionClick();
//                         setSheetState(
//                           () => selectedColorValue = color.value,
//                         );
//                       },
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 6),
//                         padding: const EdgeInsets.all(4),
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                             color: isSelected ? color : Colors.transparent,
//                             width: 2,
//                           ),
//                         ),
//                         child: CircleAvatar(
//                           radius: 14,
//                           backgroundColor: color,
//                         ),
//                       ),
//                     )
//                         .animate(target: isSelected ? 1 : 0)
//                         .scaleXY(end: 1.2, duration: 200.ms);
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 24),
//                 const Text(
//                   'Journey Icon',
//                   style: TextStyle(color: Colors.white70, fontSize: 14),
//                 ),
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 12,
//                   runSpacing: 12,
//                   alignment: WrapAlignment.center,
//                   children: availableIcons.entries.map((entry) {
//                     final isSelected = selectedIconKey == entry.key;
//                     return GestureDetector(
//                       onTap: () {
//                         HapticFeedback.selectionClick();
//                         setSheetState(() => selectedIconKey = entry.key);
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           color: isSelected
//                               ? const Color(
//                                   0xFF00E5FF,
//                                 ).withOpacity(0.2)
//                               : Colors.white.withOpacity(0.05),
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                             color: isSelected
//                                 ? const Color(0xFF00E5FF)
//                                 : Colors.transparent,
//                             width: 2,
//                           ),
//                         ),
//                         child: Icon(
//                           entry.value,
//                           color: isSelected
//                               ? const Color(0xFF00E5FF)
//                               : Colors.white54,
//                         ),
//                       ),
//                     )
//                         .animate(target: isSelected ? 1 : 0)
//                         .scaleXY(end: 1.1, duration: 200.ms);
//                   }).toList(),
//                 ),
//                 const SizedBox(height: 12),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
