import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_avatar.freezed.dart';
part 'user_avatar.g.dart';

/// The type of user avatar source.
enum UserAvatarType {
  /// Default: show the initial character "我" on a green background.
  none,

  /// A single emoji character displayed as the avatar.
  emoji,

  /// A remote image URL (e.g. QQ avatar, any HTTPS link).
  url,

  /// A local file path (picked from gallery and optionally cropped).
  file,
}

/// User avatar configuration, persisted as a JSON blob via the settings store.
@freezed
abstract class UserAvatar with _$UserAvatar {
  const factory UserAvatar({
    @Default(UserAvatarType.none) UserAvatarType type,

    /// The value depends on [type]:
    ///   - [UserAvatarType.none]: ignored (null or empty).
    ///   - [UserAvatarType.emoji]: the emoji string (e.g. "😊").
    ///   - [UserAvatarType.url]: the full HTTPS URL.
    ///   - [UserAvatarType.file]: the local file path.
    @Default('') String value,

    /// Custom display name for the user; empty means the default "用户".
    @Default('') String name,
  }) = _UserAvatar;

  factory UserAvatar.fromJson(Map<String, dynamic> json) =>
      _$UserAvatarFromJson(json);
}
