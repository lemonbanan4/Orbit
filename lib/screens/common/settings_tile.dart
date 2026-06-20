import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData leadingIcon;
  final Color leadingIconColor;
  final String title;
  final String? subtitle;
  final Color titleColor;
  final Widget? trailing;
  final bool showChevron;

  const SettingsTile({
    super.key,
    required this.onTap,
    required this.leadingIcon,
    required this.title,
    this.leadingIconColor = Colors.white,
    this.titleColor = Colors.white,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(leadingIcon, color: leadingIconColor),
      title: Text(title,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 12))
          : null,
      trailing: trailing ??
          (showChevron
              ? const Icon(Icons.chevron_right_rounded, color: Colors.white54)
              : null),
    );
  }
}
