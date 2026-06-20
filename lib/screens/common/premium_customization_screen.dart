import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';

class PremiumCustomizationScreen extends StatefulWidget {
  const PremiumCustomizationScreen({super.key});

  @override
  State<PremiumCustomizationScreen> createState() =>
      _PremiumCustomizationScreenState();
}

class _PremiumCustomizationScreenState
    extends State<PremiumCustomizationScreen> {
  String? _currentIconName;

  @override
  void initState() {
    super.initState();
    _fetchCurrentIcon();
  }

  Future<void> _fetchCurrentIcon() async {
    try {
      setState(() {
        _currentIconName = 'default';
      });
    } catch (e) {
      debugPrint("Failed to fetch current icon: $e");
    }
  }

  Future<void> _changeAppIcon(String iconName) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Dynamic icons are temporarily disabled in this version.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to change app icon: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    // You will need to define these alternative icons in your Info.plist (iOS)
    // and AndroidManifest.xml (Android) for them to work!
    final icons = [
      {
        'name': 'default',
        'label': 'Orbit Classic',
        'icon': Icons.rocket_launch_rounded
      },
      {
        'name': 'dark_matter',
        'label': 'Dark Matter',
        'icon': Icons.nights_stay_rounded
      },
      {
        'name': 'stellar_gold',
        'label': 'Stellar Gold',
        'icon': Icons.star_rounded
      },
    ];

    return BaseOrbitScreen(
      title: 'Pro Customization',
      body: ListView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        children: [
          Text(
            'App Icons',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ...icons.map((icon) {
            final isSelected = _currentIconName == icon['name'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PremiumGlassCard(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00E5FF)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(icon['icon'] as IconData,
                        color: isSelected ? const Color(0xFF00E5FF) : textColor,
                        size: 28),
                  ),
                  title: Text(
                    icon['label'] as String,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00E5FF))
                      : OutlinedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _changeAppIcon(icon['name'] as String);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: textColor.withValues(alpha: 0.3)),
                          ),
                          child: Text('Select',
                              style: TextStyle(color: textColor)),
                        ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
