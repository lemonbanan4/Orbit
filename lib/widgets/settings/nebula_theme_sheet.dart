import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/routine_provider.dart';
import '../../theme/nebula_themes.dart';
import '../../theme/orbit_tokens.dart';
import '../../utils/dev_overrides.dart';

/// Lets the user preview, unlock (via XP), and switch between Nebula
/// Themes — the app-wide accent pair rendered through the [OrbitColors]
/// theme extension. Mirrors the purchase flow in
/// `widgets/dashboard/streak_freeze_sheet.dart`.
class NebulaThemeSheet extends StatelessWidget {
  const NebulaThemeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NebulaThemeSheet(),
    );
  }

  Future<void> _select(BuildContext context, NebulaTheme theme) async {
    final provider = context.read<RoutineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isUnlocked = provider.unlockedThemes.contains(theme.name);

    if (isUnlocked) {
      provider.setActiveNebulaTheme(theme.name);
      return;
    }

    final error = await provider.unlockTheme(theme.name);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
      return;
    }
    provider.setActiveNebulaTheme(theme.name);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${theme.name} unlocked and applied.'),
        backgroundColor: theme.orbColor1.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
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
                  'Nebula Theme',
                  style: TextStyle(
                    color: OrbitTokens.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Recolor Orbit\'s glow. Unlock a theme with XP, then switch '
                  'freely between the ones you own.',
                  style: TextStyle(
                    color: OrbitTokens.inkDim,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ...NebulaThemes.all.map(
                  (theme) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ThemeRow(
                      theme: theme,
                      isUnlocked: provider.unlockedThemes.contains(theme.name),
                      isActive: provider.activeNebulaTheme == theme.name,
                      isBusy: provider.isBuyingTheme,
                      canAfford: DevOverrides.storeIsFreeInDebug ||
                          provider.xp >= theme.cost,
                      onTap: () => _select(context, theme),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'You have ${provider.xp} XP · earn 10 per habit',
                    style: const TextStyle(
                      color: OrbitTokens.inkFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final NebulaTheme theme;
  final bool isUnlocked;
  final bool isActive;
  final bool isBusy;
  final bool canAfford;
  final VoidCallback onTap;

  const _ThemeRow({
    required this.theme,
    required this.isUnlocked,
    required this.isActive,
    required this.isBusy,
    required this.canAfford,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isBusy || (!isUnlocked && !canAfford);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OrbitTokens.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? theme.orbColor1 : OrbitTokens.hairline,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.orbColor1, theme.orbColor2],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(
                      color: OrbitTokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    theme.description,
                    style: const TextStyle(
                      color: OrbitTokens.inkDim,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isActive)
              Icon(Icons.check_circle_rounded, color: theme.orbColor1)
            else if (isUnlocked)
              Text(
                'Apply',
                style: TextStyle(
                  color: OrbitTokens.inkDim,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: canAfford ? OrbitTokens.gold : OrbitTokens.inkFaint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${theme.cost} XP',
                    style: TextStyle(
                      color:
                          canAfford ? OrbitTokens.gold : OrbitTokens.inkFaint,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
