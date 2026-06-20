import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_fairy_service.dart';
import 'ai_fairy_bubble.dart';

class FairySection extends StatefulWidget {
  final String habitName;

  const FairySection({super.key, required this.habitName});

  @override
  State<FairySection> createState() => _FairySectionState();
}

class _FairySectionState extends State<FairySection> {
  final AIFairyService _fairyService = AIFairyService();
  late Future<AIFairyResponse> _fairyFuture;

  @override
  void initState() {
    super.initState();
    _fairyFuture = _fairyService.getFairyInteraction(widget.habitName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<AIFairyResponse>(
      future: _fairyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }

        if (!snapshot.hasData) return const SizedBox.shrink();

        final fairy = snapshot.data!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AIFairyBubble(message: fairy.text),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: fairy.options.map((option) {
                return ActionChip(
                  elevation: 4,
                  backgroundColor: Colors.purpleAccent.withValues(alpha: 0.15),
                  side: BorderSide(
                      color: Colors.purpleAccent.withValues(alpha: 0.3)),
                  label: Text(option,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12)),
                  onPressed: () {
                    HapticFeedback.lightImpact();

                    // Save the interaction to Firestore
                    _fairyService.saveInteraction(
                        widget.habitName, fairy.text, option);

                    setState(() {
                      _fairyFuture = _fairyService.getFairyInteraction(
                          "The user replied: $option. Respond briefly with a blessing.");
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
