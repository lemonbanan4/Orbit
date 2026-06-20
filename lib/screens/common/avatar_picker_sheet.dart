import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/avatar_option.dart';

class AvatarPickerSheet extends StatelessWidget {
  const AvatarPickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const AvatarPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = context.watch<RoutineProvider>().selectedAvatar;

    return PremiumGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose AI Coach Avatar',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              AvatarOption(
                  name: 'Rocket',
                  id: 'rocket',
                  icon: Icons.rocket_launch_rounded,
                  currentAvatar: currentAvatar),
              AvatarOption(
                  name: 'Astronaut',
                  id: 'astronaut',
                  icon: Icons.accessibility_new_rounded,
                  currentAvatar: currentAvatar),
              AvatarOption(
                  name: 'Alien',
                  id: 'alien',
                  icon: Icons.face_retouching_natural_rounded,
                  currentAvatar: currentAvatar),
              AvatarOption(
                  name: 'Planet',
                  id: 'planet',
                  icon: Icons.public_rounded,
                  currentAvatar: currentAvatar),
              AvatarOption(
                  name: 'Star',
                  id: 'star',
                  icon: Icons.star_rounded,
                  currentAvatar: currentAvatar),
              AvatarOption(
                  name: 'Moon',
                  id: 'moon',
                  icon: Icons.nightlight_round,
                  currentAvatar: currentAvatar),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
