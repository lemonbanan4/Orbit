// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// // FIX: The correct relative path to your navigation screen
// import '../navigation/main_navigation_screen.dart';

// class VideoScreen extends StatefulWidget {
//   const VideoScreen({super.key});

//   @override
//   State<VideoScreen> createState() => _VideoScreenState();
// }

// class _VideoScreenState extends State<VideoScreen> {
//   late VideoPlayerController _controller;
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     // Ensure your video file is in: assets/videos/premium_welcome.mp4
//     _controller =
//         VideoPlayerController.asset("assets/videos/premium_welcome.mp4")
//           ..initialize().then((_) {
//             setState(() {
//               _isInitialized = true;
//             });
//             _controller.play();
//           });

//     _controller.addListener(() {
//       // When video ends, transition to the Premium Dashboard
//       if (_controller.value.position >= _controller.value.duration &&
//           _controller.value.duration != Duration.zero) {
//         _navigateToDashboard();
//       }
//     });
//   }

//   void _navigateToDashboard() {
//     Navigator.pushReplacement(
//       context,
//       PageRouteBuilder(
//         pageBuilder: (context, animation, secondaryAnimation) =>
//             const MainNavigationScreen(),
//         transitionsBuilder: (context, animation, secondaryAnimation, child) {
//           return FadeTransition(opacity: animation, child: child);
//         },
//         transitionDuration: 800.ms,
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: _isInitialized
//             ? AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: VideoPlayer(_controller),
//               )
//             : const CircularProgressIndicator(color: Color(0xFF00E5FF)),
//       ),
//     );
//   }
// }
