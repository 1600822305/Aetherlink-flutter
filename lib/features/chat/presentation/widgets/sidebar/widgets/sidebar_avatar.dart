// Shared sidebar avatar and the assistant avatar-text helper.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// A square avatar with a centered glyph (radius 25%, white text).
/// When [image] is provided the image is rendered instead of [text].
class SidebarAvatar extends StatelessWidget {
  const SidebarAvatar({
    super.key,
    required this.text,
    required this.background,
    required this.size,
    required this.fontSize,
    this.image,
  });

  final String text;
  final Color background;
  final double size;
  final double fontSize;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.25),
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
      ),
      child: image != null
          ? null
          : Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                height: 1,
                color: Colors.white,
              ),
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

/// Decodes a base64 data URL avatar into a [MemoryImage], or returns `null`.
MemoryImage? assistantAvatarImage(Assistant a) {
  final url = a.avatar;
  if (url == null || url.isEmpty) return null;
  final marker = url.indexOf('base64,');
  if (marker < 0) return null;
  try {
    return MemoryImage(base64Decode(url.substring(marker + 7)));
  } on FormatException {
    return null;
  }
}
