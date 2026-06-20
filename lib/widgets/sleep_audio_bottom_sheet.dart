// lib/widgets/sleep_audio_bottom_sheet.dart

import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SleepAudioBottomSheet extends StatefulWidget {
  const SleepAudioBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SleepAudioBottomSheet(),
    );
  }

  @override
  State<SleepAudioBottomSheet> createState() => _SleepAudioBottomSheetState();
}

class _SleepAudioBottomSheetState extends State<SleepAudioBottomSheet>
    with TickerProviderStateMixin {
  double _frequencyVolume = 0.5;
  bool _isPlaying = false;
  int _selectedWaveIndex = 0;
  bool _isFadingOut = false;

  // Declare the persistent AudioPlayer engine instance context
  late AudioPlayer _audioPlayer;

  // Real cosmic frequency mappings for deep relaxation states
  final List<Map<String, dynamic>> _frequencies = [
    {
      'title': 'Deep Space Void',
      'hz': '432 Hz',
      'wave': 'Delta Brainwaves',
      'desc':
          'Targeting deep healing stages, REM cycles, and mental decompression.',
      'color': const Color(0xFF00E5FF),
      'auraDuration': 3000,
      'coreDuration': 2000,
      'asset': 'audio/void_432.mp3',
    },
    {
      'title': 'Solar Wind Harmony',
      'hz': '528 Hz',
      'wave': 'Theta Resonance',
      'desc':
          'The cellular restoration frequency. Shuts down nighttime overthinking.',
      'color': Colors.purpleAccent,
      'auraDuration': 2000,
      'coreDuration': 1200,
      'asset': 'audio/solar_528.mp3',
    },
    {
      'title': 'Stellar Pulse',
      'hz': '7.83 Hz',
      'wave': 'Schumann Resonance',
      'desc':
          'Earth\'s electromagnetic heartbeat. Grounding hyper-active neural orbits.',
      'color': Colors.amberAccent,
      'auraDuration': 1000,
      'coreDuration': 600,
      'asset': 'audio/ground_7.83.mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the AudioPlayer instance here to persist across widget rebuilds
    _audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(_frequencyVolume);

    // Fallback guarantee to ensure the track loops infinitely
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && _isPlaying) {
        _audioPlayer.resume();
      }
    });
  }

  @override
  void dispose() {
    // CRITICAL: Always release hardware resources when the user closes the modal sheet
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    HapticFeedback.mediumImpact();

    if (_isFadingOut) return; // Prevent double-taps during fade

    if (_isPlaying) {
      _isFadingOut = true;
      setState(() => _isPlaying = false);

      // Slowly fade out over ~1 second
      double vol = _frequencyVolume;
      while (vol > 0.05 && mounted) {
        vol -= 0.05;
        await _audioPlayer.setVolume(vol);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        await _audioPlayer.pause();
        await _audioPlayer.setVolume(
          _frequencyVolume,
        ); // Reset volume for next time
      }
      _isFadingOut = false;
    } else {
      final currentFreq = _frequencies[_selectedWaveIndex];
      await _audioPlayer.setVolume(_frequencyVolume);

      try {
        await _audioPlayer.play(AssetSource(currentFreq['asset'] as String));
        setState(() => _isPlaying = true);
      } catch (e) {
        // Handle audio playback errors gracefully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleFrequencyChange(int index) async {
    if (_selectedWaveIndex == index || _isFadingOut) return;
    HapticFeedback.selectionClick();

    if (_isPlaying) {
      _isFadingOut = true;

      // Smoothly dip the volume before switching
      double vol = _frequencyVolume;
      while (vol > 0.05 && mounted) {
        vol -= 0.1;
        if (vol < 0) vol = 0;
        await _audioPlayer.setVolume(vol);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (!mounted) return;
      setState(() {
        _selectedWaveIndex = index;
      });

      final currentFreq = _frequencies[_selectedWaveIndex];
      await _audioPlayer.setVolume(0.0); // Start new track at 0 volume

      try {
        await _audioPlayer.play(AssetSource(currentFreq['asset'] as String));

        // Smoothly raise the volume back up
        vol = 0.0;
        while (vol < _frequencyVolume && mounted) {
          vol += 0.1;
          if (vol > _frequencyVolume) vol = _frequencyVolume;
          await _audioPlayer.setVolume(vol);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error switching audio: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      _isFadingOut = false;
    } else {
      setState(() {
        _selectedWaveIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFreq = _frequencies[_selectedWaveIndex];
    final Color engineColor = currentFreq['color'] as Color;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.only(
            top: 16,
            left: 28,
            right: 28,
            bottom: 40,
          ),
          decoration: BoxDecoration(
            //color: const Color(0xFF060314).withValues(alpha: 0.92),
            color: Color.lerp(
              const Color(0xFF060314),
              engineColor,
              0.12,
            )!.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Drag bar
              Container(
                width: 42,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                "COSMIC BINAURAL GENERATOR",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentFreq['title'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "${currentFreq['hz']} — ${currentFreq['wave']}",
                style: TextStyle(
                  color: engineColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
              const SizedBox(height: 35),

              // THE PULSING FREQUENCY HARMONIZER GRAPHIC
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer aura ring 1
                    Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: engineColor.withValues(
                                alpha: _isPlaying ? 0.3 : 0.05,
                              ),
                              width: 1,
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 0.9,
                          end: 1.25,
                          duration: Duration(
                            milliseconds: currentFreq['auraDuration'] as int,
                          ),
                          curve: Curves.easeInOut,
                        ),

                    // Inner glowing core orb
                    Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                engineColor.withValues(
                                  alpha: _isPlaying ? 0.4 : 0.15,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.waves_rounded
                                : Icons.radio_button_off_rounded,
                            color: _isPlaying ? Colors.white : Colors.white30,
                            size: 32,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                          begin: 0.95,
                          end: 1.05,
                          duration: Duration(
                            milliseconds: currentFreq['coreDuration'] as int,
                          ),
                          curve: Curves.easeInOut,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // WAVE DESCRIPTOR BLOCK
              SizedBox(
                height: 45,
                child: Text(
                  currentFreq['desc'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // FREQUENCY MATRIX TUNER SECTOR (Horizontal Wave Swapper)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _frequencies.asMap().entries.map((entry) {
                  int idx = entry.key;
                  bool isSelected = idx == _selectedWaveIndex;
                  return GestureDetector(
                    onTap: () {
                      _handleFrequencyChange(idx);
                    },
                    child: AnimatedContainer(
                      duration: 250.ms,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                        border: Border.all(
                          color: isSelected
                              ? engineColor.withValues(alpha: 0.4)
                              : Colors.white10,
                        ),
                      ),
                      child: Text(
                        entry.value['hz'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 35),

              // VOLUME CONTROLLER TRACK
              Row(
                children: [
                  const Icon(
                    Icons.volume_mute_rounded,
                    color: Colors.white24,
                    size: 16,
                  ),
                  Expanded(
                    child: Slider(
                      value: _frequencyVolume,
                      activeColor: engineColor,
                      inactiveColor: Colors.white10,
                      onChanged: (val) {
                        setState(() {
                          _frequencyVolume = val;
                          _audioPlayer.setVolume(val);
                        });
                      },
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    color: engineColor.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // THE CORE QUANTUM TRIGGER SWITCH
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: engineColor, width: 1.5),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    backgroundColor: engineColor.withValues(
                      alpha: _isPlaying ? 0.06 : 0.0,
                    ),
                  ),
                  onPressed: _togglePlayback,
                  child: Text(
                    _isPlaying
                        ? "HALT RESONANCE FIELD"
                        : "EMIT DEEP RECOVERY FREQUENCY",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
