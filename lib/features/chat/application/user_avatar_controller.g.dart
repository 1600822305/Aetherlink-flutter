// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_avatar_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the user's avatar. Persisted as a single JSON blob in the
/// Drift key/value store; survives app restart.

@ProviderFor(UserAvatarController)
final userAvatarControllerProvider = UserAvatarControllerProvider._();

/// Controller for the user's avatar. Persisted as a single JSON blob in the
/// Drift key/value store; survives app restart.
final class UserAvatarControllerProvider
    extends $NotifierProvider<UserAvatarController, UserAvatar> {
  /// Controller for the user's avatar. Persisted as a single JSON blob in the
  /// Drift key/value store; survives app restart.
  UserAvatarControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userAvatarControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userAvatarControllerHash();

  @$internal
  @override
  UserAvatarController create() => UserAvatarController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserAvatar value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserAvatar>(value),
    );
  }
}

String _$userAvatarControllerHash() =>
    r'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0';

/// Controller for the user's avatar. Persisted as a single JSON blob in the
/// Drift key/value store; survives app restart.

abstract class _$UserAvatarController extends $Notifier<UserAvatar> {
  UserAvatar build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UserAvatar, UserAvatar>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserAvatar, UserAvatar>,
              UserAvatar,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
