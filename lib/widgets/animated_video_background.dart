import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedVideoBackground extends StatefulWidget {
  final String videoPath;

  const AnimatedVideoBackground({super.key, required this.videoPath});

  @override
  State<AnimatedVideoBackground> createState() =>
      _AnimatedVideoBackgroundState();
}

class _AnimatedVideoBackgroundState extends State<AnimatedVideoBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        _controller.setVolume(0.0); // Keep it strictly ambient/muted
        _controller.setLooping(true);
        _controller.play();

        if (mounted) {
          setState(() => _isInitialized = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isInitialized ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
