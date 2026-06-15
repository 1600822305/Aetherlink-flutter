import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the four dependency-boundary rules from `docs/PROJECT_STRUCTURE.md`
/// §5 / `docs/CONVENTIONS.md` §2 at CI time.
///
/// This is the substitute for a `custom_lint` boundary plugin: the latest
/// `custom_lint` only supports analyzer ^8, which is incompatible with the
/// analyzer ^10+ required by this SDK's codegen toolchain. Scanning imports in a
/// test gives the same "fail the build on violation" guarantee without the
/// version conflict. Migrate to a `custom_lint` plugin once it supports
/// analyzer ^10+.
///
/// Rules enforced:
///   1. `presentation` must not import `data`.
///   2. `domain` must not import framework / IO packages (stays pure Dart).
///   3. feature A must not import feature B's internals (only B's `domain`).
///   4. `core` / `shared` must not import `features`; `core` must not import
///      `shared`.
void main() {
  const packageName = 'aetherlink_flutter';
  const packagePrefix = 'package:$packageName/';

  /// Packages that the `domain` layer is forbidden from importing so it stays
  /// pure Dart (no Flutter / IO / framework dependency).
  const frameworkAndIoImports = <String>[
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:riverpod/',
    'package:riverpod_annotation/',
    'package:dio/',
    'package:drift/',
    'package:sqlite3/',
    'package:sqlite3_flutter_libs/',
    'package:path_provider/',
    'dart:io',
    'dart:ui',
    'dart:isolate',
  ];

  final libDir = Directory('lib');
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isGenerated(file.path))
      .toList();

  final violations = <String>[];

  for (final file in dartFiles) {
    final libPath = _toPosix(file.path); // e.g. lib/features/chat/...
    final imports = _importsOf(file);

    final segments = libPath.split('/');
    final feature = _featureOf(segments);

    for (final import in imports) {
      final isInternal = import.startsWith(packagePrefix);
      final internalPath = isInternal
          ? 'lib/${import.substring(packagePrefix.length)}'
          : null;

      // Rule 1: presentation must not import data.
      if (_isIn(libPath, 'presentation') &&
          internalPath != null &&
          _isIn(internalPath, 'data')) {
        violations.add('[presentation→data] $libPath imports $import');
      }

      // Rule 2: domain must stay pure Dart.
      if (_isIn(libPath, 'domain')) {
        for (final banned in frameworkAndIoImports) {
          if (import == banned || import.startsWith(banned)) {
            violations.add('[domain→framework/io] $libPath imports $import');
          }
        }
      }

      // Rule 3: feature A must not import feature B's internals.
      if (feature != null && internalPath != null) {
        final targetFeature = _featureOf(internalPath.split('/'));
        if (targetFeature != null &&
            targetFeature != feature &&
            !_isIn(internalPath, 'domain')) {
          violations.add(
            '[feature→feature internal] $libPath imports $import '
            '(only $targetFeature\'s domain is allowed)',
          );
        }
      }

      // Rule 4: core/shared must not import features; core must not import
      // shared.
      //
      // Narrow exception — the persistence composition root: the single Drift
      // database under `core/database/` is the one place that must aggregate
      // every feature's tables + DAOs (a single SQLite file). Those definitions
      // can only live in their owning feature's `data` layer, because their
      // JSON-blob `TypeConverter`s reference the domain models being persisted.
      // The generated database part also names those domain entities directly,
      // so `core/database/` may import (a) feature `data/datasources`
      // definitions and (b) the pure-Dart `domain` entities they persist — the
      // database equivalent of how `app/` composes features. This stays narrow:
      // only `core/database/`, only feature `data` files and `domain` entities
      // (which import no frameworks, per Rule 2); every other
      // `core → features/shared` import still fails.
      if (internalPath != null) {
        final isDbCompositionRoot =
            _isIn(libPath, 'core') && _isIn(libPath, 'database');
        final importsFeatureData =
            _isIn(internalPath, 'features') && _isIn(internalPath, 'data');
        final importsDomain = _isIn(internalPath, 'domain');
        final allowedDbComposition =
            isDbCompositionRoot && (importsFeatureData || importsDomain);

        if (_isIn(libPath, 'core') &&
            (_isIn(internalPath, 'features') ||
                _isIn(internalPath, 'shared')) &&
            !allowedDbComposition) {
          violations.add(
            '[core→${_topOf(internalPath)}] $libPath '
            'imports $import',
          );
        }
        if (_isIn(libPath, 'shared') && _isIn(internalPath, 'features')) {
          violations.add('[shared→features] $libPath imports $import');
        }
      }
    }
  }

  test('lib/ respects all four dependency-boundary rules', () {
    expect(
      dartFiles,
      isNotEmpty,
      reason: 'no Dart files were scanned under lib/ — check the test setup',
    );
    expect(
      violations,
      isEmpty,
      reason: 'dependency-boundary violations found:\n${violations.join('\n')}',
    );
  });
}

/// Whether [path] contains [segment] as a full path segment.
bool _isIn(String path, String segment) => path.split('/').contains(segment);

/// The top-level `lib/<top>` segment of an internal path, e.g. `features`.
String _topOf(String libPath) {
  final segments = libPath.split('/');
  return segments.length >= 2 ? segments[1] : segments.last;
}

/// The feature name for a `lib/features/<name>/...` path, or null.
String? _featureOf(List<String> segments) {
  final index = segments.indexOf('features');
  if (index == -1 || index + 1 >= segments.length) {
    return null;
  }
  return segments[index + 1];
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.drift.dart');

String _toPosix(String path) => path.replaceAll(r'\', '/');

final _importPattern = RegExp(
  '''^\\s*import\\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<String> _importsOf(File file) {
  final content = file.readAsStringSync();
  return _importPattern
      .allMatches(content)
      .map((match) => match.group(1)!)
      .toList();
}
