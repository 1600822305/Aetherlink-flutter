// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The skill library, persisted through the app-level key/value store as a JSON
/// list — the port of the web `SkillManager` (CRUD / toggle / built-in
/// initialization / import-export / usage stats). The built-in catalog
/// ([kBuiltinSkills]) is seeded on first run and any newly-shipped built-in is
/// merged in on later builds; built-in skills can be disabled but not deleted.
///
/// Assistant binding lives in the chat-owned `Assistants` notifier (a skill is
/// bound by storing its id on `assistant.skillIds`); this controller only owns
/// the skills themselves.

@ProviderFor(Skills)
final skillsProvider = SkillsProvider._();

/// The skill library, persisted through the app-level key/value store as a JSON
/// list — the port of the web `SkillManager` (CRUD / toggle / built-in
/// initialization / import-export / usage stats). The built-in catalog
/// ([kBuiltinSkills]) is seeded on first run and any newly-shipped built-in is
/// merged in on later builds; built-in skills can be disabled but not deleted.
///
/// Assistant binding lives in the chat-owned `Assistants` notifier (a skill is
/// bound by storing its id on `assistant.skillIds`); this controller only owns
/// the skills themselves.
final class SkillsProvider extends $AsyncNotifierProvider<Skills, List<Skill>> {
  /// The skill library, persisted through the app-level key/value store as a JSON
  /// list — the port of the web `SkillManager` (CRUD / toggle / built-in
  /// initialization / import-export / usage stats). The built-in catalog
  /// ([kBuiltinSkills]) is seeded on first run and any newly-shipped built-in is
  /// merged in on later builds; built-in skills can be disabled but not deleted.
  ///
  /// Assistant binding lives in the chat-owned `Assistants` notifier (a skill is
  /// bound by storing its id on `assistant.skillIds`); this controller only owns
  /// the skills themselves.
  SkillsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillsHash();

  @$internal
  @override
  Skills create() => Skills();
}

String _$skillsHash() => r'611446c693a16aa9ddc8d50931606d134289c048';

/// The skill library, persisted through the app-level key/value store as a JSON
/// list — the port of the web `SkillManager` (CRUD / toggle / built-in
/// initialization / import-export / usage stats). The built-in catalog
/// ([kBuiltinSkills]) is seeded on first run and any newly-shipped built-in is
/// merged in on later builds; built-in skills can be disabled but not deleted.
///
/// Assistant binding lives in the chat-owned `Assistants` notifier (a skill is
/// bound by storing its id on `assistant.skillIds`); this controller only owns
/// the skills themselves.

abstract class _$Skills extends $AsyncNotifier<List<Skill>> {
  FutureOr<List<Skill>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Skill>>, List<Skill>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Skill>>, List<Skill>>,
              AsyncValue<List<Skill>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
