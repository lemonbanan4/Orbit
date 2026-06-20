import 'package:flutter/material.dart';

class SignInButton extends StatelessWidget {
  final String text;
  final String? imagePath;
  final IconData? iconData;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const SignInButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.imagePath,
    this.iconData,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
  }) : assert(imagePath != null || iconData != null,
            'Either imagePath or iconData must be provided.');

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imagePath != null)
            Image.asset(imagePath!, height: 24, width: 24)
          else if (iconData != null)
            Icon(iconData!, size: 28), // Slightly larger for Apple icon
          const SizedBox(width: 12),
          Text(text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
