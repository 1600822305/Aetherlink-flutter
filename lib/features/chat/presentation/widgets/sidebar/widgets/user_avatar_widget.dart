// Renders the user's avatar based on [UserAvatar] type: default initial, emoji,
// remote URL, or local file.

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/shared/domain/user_avatar.dart';

/// The default avatar background color (`#87d068`).
const Color _defaultAvatarBg = Color(0xFF87D068);

/// Displays the user avatar, adapting its content to the configured
/// [UserAvatarType]: the "我" initial, an emoji, a network image, or a local
/// file image. Falls back to the green initial on load errors.
class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    super.key,
    required this.avatar,
    this.size = 36,
  });

  final UserAvatar avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (avatar.type) {
      case UserAvatarType.emoji:
        return Container(
          color: _defaultAvatarBg,
          alignment: Alignment.center,
          child: Text(
            avatar.value,
            style: TextStyle(fontSize: size * 0.55, height: 1),
          ),
        );
      case UserAvatarType.url:
        return Image.network(
          avatar.value,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(),
        );
      case UserAvatarType.file:
        final file = File(avatar.value);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover);
        }
        return _defaultAvatar();
      case UserAvatarType.none:
        return _defaultAvatar();
    }
  }

  Widget _defaultAvatar() {
    return Container(
      color: _defaultAvatarBg,
      alignment: Alignment.center,
      child: Text(
        '我',
        style: TextStyle(
          fontSize: size * 0.636,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
