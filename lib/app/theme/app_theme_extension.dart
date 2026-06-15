import 'package:flutter/material.dart';

/// Custom component styling that has no home in stock `ThemeData` — chat-bubble
/// colors and the shared corner radius (ADR-0008: "custom component styles hang
/// off a `ThemeExtension`"). Widgets read it via
/// `Theme.of(context).extension<AppThemeExtension>()`.
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.bubbleUser,
    required this.bubbleAi,
    required this.borderRadius,
  });

  final Color bubbleUser;
  final Color bubbleAi;
  final double borderRadius;

  @override
  AppThemeExtension copyWith({
    Color? bubbleUser,
    Color? bubbleAi,
    double? borderRadius,
  }) {
    return AppThemeExtension(
      bubbleUser: bubbleUser ?? this.bubbleUser,
      bubbleAi: bubbleAi ?? this.bubbleAi,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      bubbleUser: Color.lerp(bubbleUser, other.bubbleUser, t)!,
      bubbleAi: Color.lerp(bubbleAi, other.bubbleAi, t)!,
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
