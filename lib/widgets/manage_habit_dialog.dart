import 'package:flutter/material.dart';

class ManageHabitDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String habitId,
    required String habitTitle,
    required String sessionType,
    required int iconCodePoint,
    required VoidCallback onDelete,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1F36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                ),
              ),
              title: const Text(
                "Delete Habit",
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                "Are you sure you want to delete the habit '$habitTitle' from the $sessionType session?",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                    onDelete();
                  },
                  child: const Text(
                    "Delete",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
