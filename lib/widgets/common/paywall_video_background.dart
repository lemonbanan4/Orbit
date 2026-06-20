import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PaywallVideoBackground extends StatefulWidget {
  final double overlayOpacity;

  const PaywallVideoBackground({
    super.key,
    this.overlayOpacity =
        0.3, // Subtle dark vignette to make your white text pop beautifully
  });

  @override
  State<PaywallVideoBackground> createState() => _PaywallVideoBackgroundState();
}

class _PaywallVideoBackgroundState extends State<PaywallVideoBackground> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/orbit-mvp-54642.firebasestorage.app/o/paywall_bg.mp4?alt=media';

      // Fetch from cache instantly if it exists, otherwise pull down smoothly in background
      final file = await DefaultCacheManager().getSingleFile(url);

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setVolume(0.0);
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (error) {
      debugPrint("Error initializing paywall video matrix lines: $error");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🌌 1. Deep cosmic fallback color (displays instantly while cache checks run)
        const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF020205))),

        // 🎬 2. The Native Crisp Video Layer
        if (_isInitialized && _controller != null)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

        // 🛡️ 3. Premium Overlay Mask (Removed the blur, keeping text contrast perfectly sharp)
        ColoredBox(
          color: Colors.black.withValues(alpha: widget.overlayOpacity),
        ),
      ],
    );
  }
}
