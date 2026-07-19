import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/interest_options.dart';
import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';

/// Lets the user edit their focus interests after onboarding — previously
/// the multi-select grid in the onboarding survey was the only place they
/// could ever be set, locking Daily Wisdom / AI-coach personalization to a
/// one-time choice. Mirrors the sheet styling of NebulaThemeSheet.
class InterestsSheet extends StatefulWidget {
  const InterestsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const InterestsSheet(),
    );
  }

  @override
  State<InterestsSheet> createState() => _InterestsSheetState();
}

class _InterestsSheetState extends State<InterestsSheet> {
  late Set<String> _selected;
  // Entries in the user's interests array that aren't canonical options
  // (past_journeys_screen.dart arrayUnions completed-journey habit titles
  // in as coach focus areas) — preserved untouched on save, just not
  // shown as chips.
  late List<String> _nonCanonical;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<RoutineProvider>().interests;
    _selected = current.where(interestOptions.contains).toSet();
    _nonCanonical =
        current.where((i) => !interestOptions.contains(i)).toList();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final provider = context.read<RoutineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await provider.setInterests([
      ...interestOptions.where(_selected.contains),
      ..._nonCanonical,
    ]);

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'Interests updated — your Daily Wisdom will follow.',
        ),
        backgroundColor: OrbitTokens.teal.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: OrbitTokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Focus Interests',
              style: TextStyle(
                color: OrbitTokens.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'These steer your Daily Wisdom scrolls and what the AI coach '
              'focuses on. Pick as many as you like.',
              style: TextStyle(
                color: OrbitTokens.inkDim,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interestOptions.map((option) {
                    final isSelected = _selected.contains(option);
                    return FilterChip(
                      label: Text(option),
                      selected: isSelected,
                      onSelected: (v) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          v ? _selected.add(option) : _selected.remove(option);
                        });
                      },
                      backgroundColor: OrbitTokens.surface2,
                      selectedColor: OrbitTokens.teal.withValues(alpha: 0.2),
                      checkmarkColor: OrbitTokens.teal,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : OrbitTokens.inkDim,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? OrbitTokens.teal
                            : OrbitTokens.hairline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: OrbitTokens.signal,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: OrbitTokens.ground,
                          ),
                        )
                      : const Text(
                          'Save Interests',
                          style: TextStyle(
                            color: OrbitTokens.ground,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
