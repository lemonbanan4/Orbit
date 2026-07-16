import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../theme/orbit_colors.dart';
import '../../theme/orbit_tokens.dart';

// --- NOTIFICATIONS SCREEN ---

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    // The app's brand accent (orange in dark mode, cyan in light) — this
    // screen renders in both themes via BaseOrbitScreen.
    final accent =
        theme.extension<OrbitColors>()?.orbColor1 ?? const Color(0xFF00E5FF);

    return BaseOrbitScreen(
      title: 'Notifications',
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: textColor.withValues(alpha: 0.5),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Inbox'),
                Tab(text: 'Scheduled'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInboxTab(textColor, accent),
                  _ScheduledAlarmsTab(textColor: textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxTab(Color textColor, Color accent) {
    final user = FirebaseAuth.instance.currentUser;
    return user == null
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading notifications',
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final activeDocs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['isArchived'] != true;
              }).toList();

              if (activeDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 80,
                        color: textColor.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: activeDocs.length,
                itemBuilder: (context, index) {
                  final doc = activeDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Notification';
                  final body = data['body'] ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final type = data['type'] as String?;
                  final timeString = _formatTimestamp(timestamp);

                  IconData getIcon() {
                    if (type == 'milestone') return Icons.stars_rounded;
                    if (title.contains('Welcome')) {
                      return Icons.rocket_launch_rounded;
                    }
                    if (title.contains('Friend')) {
                      return Icons.group_add_rounded;
                    }
                    return Icons.notifications_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child:
                        Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            HapticFeedback.lightImpact();
                            doc.reference.update({'isArchived': true});
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.white,
                            ),
                          ),
                          child: PremiumGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getIcon(),
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              color: textColor.withValues(
                                                alpha: 0.5,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        body,
                                        style: TextStyle(
                                          color: textColor.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fade().slideX(
                          begin: 0.1,
                          delay: (index * 50).ms,
                        ),
                  );
                },
              );
            },
          );
  }
}

class _ScheduledAlarmsTab extends StatefulWidget {
  final Color textColor;
  const _ScheduledAlarmsTab({required this.textColor});

  @override
  State<_ScheduledAlarmsTab> createState() => _ScheduledAlarmsTabState();
}

class _ScheduledAlarmsTabState extends State<_ScheduledAlarmsTab> {
  late Future<List<PendingNotificationRequest>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _refreshAlarms();
  }

  void _refreshAlarms() {
    setState(() {
      _pendingFuture = NotificationService.getPendingNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).extension<OrbitColors>()?.orbColor1 ??
        const Color(0xFF00E5FF);
    return FutureBuilder<List<PendingNotificationRequest>>(
      future: _pendingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading scheduled alarms',
              style: TextStyle(color: widget.textColor),
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 80,
                  color: widget.textColor.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No upcoming alarms.\nThe cosmos is quiet... for now. 🚀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ).animate().fade();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Dismissible(
                key: Key(notification.id.toString()),
                direction: DismissDirection.endToStart,
                onDismissed: (_) async {
                  HapticFeedback.lightImpact();
                  // Cancel the exact alarm ID in the OS
                  await NotificationService.cancelAlarm(notification.id);
                  _refreshAlarms(); // Re-fetch the remaining alarms

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Scheduled alarm cancelled'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: OrbitTokens.surface,
                        action: SnackBarAction(
                          label: 'Undo',
                          textColor: accent,
                          onPressed: () async {
                            // Resync all routine and daily alarms from the provider
                            context.read<RoutineProvider>().resyncAllAlarms();
                            await NotificationService.scheduleDailyReminder();
                            // Wait a beat for the OS to catch up before refreshing the UI
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              _refreshAlarms,
                            );
                          },
                        ),
                      ),
                    );
                  }
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.alarm_off_rounded,
                    color: Colors.white,
                  ),
                ),
                child: PremiumGlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title ?? 'System Alert',
                              style: TextStyle(
                                color: widget.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notification.body ?? 'No details provided.',
                              style: TextStyle(
                                color: widget.textColor.withValues(alpha: 0.8),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideX(begin: 0.1, delay: (index * 50).ms),
            );
          },
        );
      },
    );
  }
}
