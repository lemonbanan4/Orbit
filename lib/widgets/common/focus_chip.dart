import 'package:flutter/material.dart';

class FocusChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const FocusChip({super.key, required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      deleteIcon: const Icon(
        Icons.close_rounded,
        size: 16,
        color: Colors.white54,
      ),
      onDeleted: onDeleted,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
