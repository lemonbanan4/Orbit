import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../extensions/widget_to_image.dart';

class ShareService {
  /// Captures a widget based on its GlobalKey and saves it as a PNG file
  /// in the system's temporary directory.
  static Future<File?> captureWidget(
      GlobalKey key, String fileNamePrefix) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final user = FirebaseAuth.instance.currentUser;
      final userName =
          user?.displayName?.replaceAll(' ', '_').toLowerCase() ?? 'astronaut';

      final pngBytes = byteData.buffer.asUint8List();
      final file = File(
          '${Directory.systemTemp.path}/${fileNamePrefix}_${userName}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      debugPrint('Error generating share image: $e');
      return null;
    }
  }

  /// Renders a widget completely off-screen and saves it as a PNG file.
  /// Perfect for creating custom sharing graphics hidden from the UI!
  static Future<File?> captureOffscreenWidget(
      Widget widget, String fileNamePrefix) async {
    try {
      final image = await widget.toImageOffscreen(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final file = File(
          '${Directory.systemTemp.path}/${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      debugPrint('Error generating offscreen share image: $e');
      return null;
    }
  }

  /// Shows a standardized bottom sheet giving the user multiple sharing options
  static void showShareBottomSheet({
    required BuildContext context,
    required File imageFile,
    required String shareText,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1F36),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1A1F36),
                    child: Icon(Icons.ios_share_rounded, color: Colors.white),
                  ),
                  title: const Text('More Options (Native)'),
                  subtitle: const Text('Share image and text via native sheet'),
                  onTap: () {
                    Navigator.pop(context);
                    Share.shareXFiles([XFile(imageFile.path)], text: shareText);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Text(
                      '𝕏',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  title: const Text('Post to 𝕏 (Twitter)'),
                  subtitle: const Text('Opens 𝕏 with pre-filled text'),
                  onTap: () async {
                    Navigator.pop(context);
                    final url = Uri.parse(
                      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareText)}',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.copy_rounded, color: Colors.white),
                  ),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.download_rounded, color: Colors.white),
                  ),
                  title: const Text('Save to Photos'),
                  subtitle: const Text('Download image to your gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await Gal.putImage(imageFile.path);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved to Photos! 📸')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Failed to save photo.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
