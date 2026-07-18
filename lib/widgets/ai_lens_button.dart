import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_coach_service.dart';
import 'create_habit_sheet.dart';

class AiLensButton extends StatelessWidget {
  const AiLensButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'ai_lens',
      onPressed: () async {
        HapticFeedback.heavyImpact();
        final picker = ImagePicker();
        XFile? image;
        try {
          image = await picker.pickImage(source: ImageSource.camera);
        } catch (e) {
          // No camera (simulator) or permission denied — picker throws
          // rather than returning null, unlike a plain cancel.
          debugPrint('AI Lens: camera unavailable: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera unavailable.')),
            );
          }
          return;
        }

        if (image != null && context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF7000FF)),
            ),
          );

          final aiSuggestion = await AiCoachService.analyzeImageForHabit(image);

          if (context.mounted) {
            Navigator.pop(context); // Dismiss loading dialog

            final Map<String, IconData> availableIcons = {
              'Explore': Icons.explore_rounded,
              'Fitness': Icons.fitness_center_rounded,
              'Book': Icons.menu_book_rounded,
              'Mind': Icons.self_improvement_rounded,
              'Sun': Icons.wb_sunny_rounded,
              'Moon': Icons.nightlight_round,
              'Work': Icons.work_rounded,
              'Heart': Icons.favorite_rounded,
            };
            final int iconCodePoint =
                (availableIcons[aiSuggestion['icon']] ?? Icons.explore_rounded)
                    .codePoint;

            CreateHabitSheet.show(
              context,
              initialTitle: aiSuggestion['title'],
              initialIcon: iconCodePoint,
            );
          }
        }
      },
      backgroundColor: const Color(0xFF7000FF), // Purple for AI
      foregroundColor: Colors.white,
      child: const Icon(Icons.document_scanner_rounded),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 2.seconds, color: Colors.white54)
        .scaleXY(
            begin: 1.0,
            end: 1.05,
            duration: 1.seconds,
            curve: Curves.easeInOut);
  }
}
