import 'package:flutter/material.dart';

class LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final int rank;
  final bool isMe;
  final VoidCallback? onRemoveFriend;

  const LeaderboardTile({
    super.key,
    required this.userData,
    required this.rank,
    required this.isMe,
    this.onRemoveFriend,
  });

  @override
  Widget build(BuildContext context) {
    final name = userData['displayName'] ?? userData['name'] ?? 'Astronaut';
    final xp = userData['xp'] ?? 0;
    final streak = userData['current_streak'] ?? userData['streakCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  rank <= 3 ? Colors.amber : Colors.white54, // Top 3 get gold
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundColor: const Color(0xFF1A1F36),
            backgroundImage: userData['avatar'] != null &&
                    userData['avatar'].toString().isNotEmpty
                ? NetworkImage(userData['avatar'])
                : null,
            child: userData['avatar'] == null
                ? const Icon(Icons.person_rounded, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$xp XP',
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (!isMe && onRemoveFriend != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.person_remove_rounded,
                color: Colors.white24,
                size: 20,
              ),
              onPressed: onRemoveFriend,
            ),
          ],
        ],
      ),
    );
  }
}
