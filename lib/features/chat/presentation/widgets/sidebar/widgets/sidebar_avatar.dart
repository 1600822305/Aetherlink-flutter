// Shared sidebar avatar and the assistant avatar-text helper.

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// A square avatar with a centered glyph (radius 25%, white text).
class SidebarAvatar extends StatelessWidget {
  const SidebarAvatar({
    super.key,
    required this.text,
    required this.background,
    required this.size,
    required this.fontSize,
  });

  final String text;
  final Color background;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, height: 1, color: Colors.white),
      ),
    );
  }
}

/// Web avatar fallback: the assistant's emoji if set, else its name's first
/// character (`assistant.emoji || name.charAt(0)`).
String assistantAvatarText(Assistant a) {
  final emoji = a.emoji;
  if (emoji != null && emoji.isNotEmpty) return emoji;
  if (a.name.isEmpty) return '?';
  return String.fromCharCodes(a.name.runes.take(1));
}
