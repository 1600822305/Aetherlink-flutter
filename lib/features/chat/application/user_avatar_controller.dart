import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/user_avatar.dart';

part 'user_avatar_controller.g.dart';

/// Storage key for the persisted user avatar setting.
const String kUserAvatarKey = 'userAvatar';

/// Controller for the user's avatar. Persisted as a single JSON blob in the
/// Drift key/value store; survives app restart.
@Riverpod(keepAlive: true)
class UserAvatarController extends _$UserAvatarController
    with JsonKvNotifier<UserAvatar> {
  @override
  ChatRepository get kvStore => ref.read(chatRepositoryProvider);

  @override
  String get storageKey => kUserAvatarKey;

  @override
  UserAvatar fromStored(Map<String, dynamic> json) => UserAvatar.fromJson(json);

  @override
  Map<String, dynamic> toStored(UserAvatar value) => value.toJson();

  @override
  UserAvatar build() => hydrate(const UserAvatar());

  /// Set the avatar to an emoji.
  void setEmoji(String emoji) => persist(
        UserAvatar(type: UserAvatarType.emoji, value: emoji),
      );

  /// Set the avatar to a remote URL (e.g. QQ avatar link).
  void setUrl(String url) => persist(
        UserAvatar(type: UserAvatarType.url, value: url),
      );

  /// Set the avatar to a local file (picked + cropped image path).
  void setFile(String path) => persist(
        UserAvatar(type: UserAvatarType.file, value: path),
      );

  /// Reset to the default avatar (initial character).
  void reset() => persist(const UserAvatar());
}
