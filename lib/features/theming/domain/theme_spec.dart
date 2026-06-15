import 'package:freezed_annotation/freezed_annotation.dart';

part 'theme_spec.freezed.dart';

/// Schema version of [ThemeSpec]. Bumped when the token set changes so imported
/// / persisted themes can be migrated forward (ADR-0008 calls for forward
/// compatibility via `schemaVersion`).
const int kThemeSpecSchemaVersion = 1;

/// Layout density of the app, mapped to a Flutter `VisualDensity` in the
/// presentation layer.
enum ThemeDensity { compact, standard, comfortable }

/// A complete, self-contained theme expressed as **data** (ADR-0008 line-rule
/// one: "theme is data, not code/CSS").
///
/// This is the single source of truth for appearance. It is pure Dart (zero
/// Flutter import) so it passes `import_boundaries_test`; the mapping to
/// `ThemeData` / `ThemeExtension` lives in the presentation/app layer. A single
/// spec carries both [ThemeColors.light] and [ThemeColors.dark] so one theme can
/// drive `MaterialApp.theme` and `MaterialApp.darkTheme` at once.
///
/// M4.0 only models the **core tokens** (colors, typography, shape, density).
/// The decoration/overlay layer and image-asset references from ADR-0008 are
/// deferred to a later theme sub-stage and will arrive behind [schemaVersion].
@freezed
abstract class ThemeSpec with _$ThemeSpec {
  const factory ThemeSpec({
    required String id,
    required String name,
    required ThemeColors colors,
    required ThemeTypography typography,
    required ThemeShape shape,
    required ThemeDensity density,
    @Default(kThemeSpecSchemaVersion) int schemaVersion,
  }) = _ThemeSpec;
}

/// The light + dark color role sets of a theme. Mirrors the `light`/`dark`
/// split of the original `themes.ts` `ThemeConfig`.
@freezed
abstract class ThemeColors with _$ThemeColors {
  const factory ThemeColors({
    required ColorRoleSet light,
    required ColorRoleSet dark,
  }) = _ThemeColors;
}

/// One brightness worth of color roles. Colors are stored as 32-bit ARGB
/// integers (`0xAARRGGBB`) to keep this type pure Dart — the presentation layer
/// wraps them in `Color`.
@freezed
abstract class ColorRoleSet with _$ColorRoleSet {
  const factory ColorRoleSet({
    required int primary,
    required int secondary,
    required int background,
    required int surface,
    required int textPrimary,
    required int textSecondary,
    required int bubbleUser,
    required int bubbleAi,
    int? accent,
  }) = _ColorRoleSet;
}

/// Typography tokens. [fontFamily] null means "use the platform default".
@freezed
abstract class ThemeTypography with _$ThemeTypography {
  const factory ThemeTypography({
    String? fontFamily,
    @Default(1.0) double textScale,
  }) = _ThemeTypography;
}

/// Shape tokens shared across components (corner rounding, etc.).
@freezed
abstract class ThemeShape with _$ThemeShape {
  const factory ThemeShape({@Default(8.0) double borderRadius}) = _ThemeShape;
}
