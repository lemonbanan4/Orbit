import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../screens/paywall/premium_checker.dart';
import 'common/premium_glass_card.dart';
import '../utils/dev_overrides.dart';

class RoutinePlayButton extends StatefulWidget {
  final String audioTitle;

  const RoutinePlayButton({super.key, required this.audioTitle});

  @override
  State<RoutinePlayButton> createState() => _RoutinePlayButtonState();
}

class _RoutinePlayButtonState extends State<RoutinePlayButton> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isPro = false;
  bool _isLoadingPro = true;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    if (DevOverrides.isProUnlocked) {
      setState(() {
        _isPro = true;
        _isLoadingPro = false;
      });
      return;
    }
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      if (customerInfo.entitlements.all["Orbit Pro"]?.isActive == true &&
          mounted) {
        setState(() => _isPro = true);
      }
    } catch (e) {
      debugPrint('Failed to check pro status: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPro = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    setState(() => _isLoading = true);
    try {
      if (_isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
      } else {
        // TODO: Replace with dynamic coaching tracks later
        await _player.play(AssetSource('audio/morning_star.mp3'));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: Color(0xFF00E5FF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Coaching',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.audioTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 32,
            color: _isPro ? const Color(0xFF00E5FF) : Colors.amber,
            icon: _isLoading || _isLoadingPro
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF),
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    !_isPro
                        ? Icons.lock_rounded
                        : (_isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded),
                  ),
            onPressed: _isLoading || _isLoadingPro
                ? null
                : () {
                    if (!_isPro) {
                      PremiumChecker.requirePro(
                        context,
                        onAccessGranted: () {
                          if (mounted) setState(() => _isPro = true);
                          _togglePlay();
                        },
                      );
                    } else {
                      _togglePlay();
                    }
                  },
          ),
        ],
      ),
    );
  }
}
