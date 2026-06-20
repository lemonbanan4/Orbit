import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';

class AvatarOption extends StatelessWidget {
  final String name;
  final String id;
  final IconData icon;
  final String currentAvatar;

  const AvatarOption({
    super.key,
    required this.name,
    required this.id,
    required this.icon,
    required this.currentAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentAvatar == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<RoutineProvider>().setAvatar(id);
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
