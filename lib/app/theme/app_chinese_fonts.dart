import 'package:flutter/material.dart';

const List<String> kSystemChineseFontFallback = [
  'system-font',
  'sans-serif',
  '.AppleSystemUIFont',
  'PingFang SC',
  'miui',
  'mipro',
  'Microsoft YaHei',
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
];

extension AppChineseTextStyle on TextStyle {
  TextStyle useSystemChineseFallback({FontWeight? fallbackFontWeight}) {
    final effectiveFontWeight = fontWeight ?? fallbackFontWeight;
    return copyWith(
      fontFamilyFallback: _mergeFontFallbacks(
        fontFamilyFallback,
        kSystemChineseFontFallback,
      ),
      fontWeight: effectiveFontWeight,
      fontVariations: _mergeWeightVariation(
        fontVariations,
        effectiveFontWeight,
      ),
    );
  }
}

extension AppChineseTextTheme on TextTheme {
  TextTheme useSystemChineseFallback() {
    return copyWith(
      displayLarge: displayLarge?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w300,
      ),
      displayMedium: displayMedium?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w300,
      ),
      displaySmall: displaySmall?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      headlineLarge: headlineLarge?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      headlineMedium: headlineMedium?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      headlineSmall: headlineSmall?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      titleLarge: titleLarge?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w500,
      ),
      titleMedium: titleMedium?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      titleSmall: titleSmall?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w500,
      ),
      bodyLarge: bodyLarge?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      bodyMedium: bodyMedium?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      bodySmall: bodySmall?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      labelLarge: labelLarge?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w500,
      ),
      labelMedium: labelMedium?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
      labelSmall: labelSmall?.useSystemChineseFallback(
        fallbackFontWeight: FontWeight.w400,
      ),
    );
  }
}

extension AppChineseThemeData on ThemeData {
  ThemeData useSystemChineseFallback() {
    return copyWith(
      textTheme: textTheme.useSystemChineseFallback(),
      primaryTextTheme: primaryTextTheme.useSystemChineseFallback(),
    );
  }
}

List<String> _mergeFontFallbacks(
  List<String>? existing,
  List<String> fallback,
) {
  final seen = <String>{};
  return [
    for (final family in [...?existing, ...fallback])
      if (seen.add(family)) family,
  ];
}

List<FontVariation>? _mergeWeightVariation(
  List<FontVariation>? existing,
  FontWeight? fontWeight,
) {
  if (fontWeight == null) {
    return existing;
  }

  final weightVariation = FontVariation.weight(fontWeight.value.toDouble());
  return [
    for (final variation in existing ?? const <FontVariation>[])
      if (variation.axis != weightVariation.axis) variation,
    weightVariation,
  ];
}
