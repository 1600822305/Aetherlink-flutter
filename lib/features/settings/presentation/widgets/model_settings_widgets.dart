import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// Shared chrome for the model-provider third-level pages (M4.3.1).
///
/// These pure-view building blocks mirror the original MUI screens
/// (`src/pages/Settings/ModelProviders/*`) so the four pages stay 1:1 without
/// duplicating the app-bar / card / form-field styling. Everything is a theme
/// token — no hardcoded hex (the avatar/letter fallbacks use `colorScheme`).

/// The original third-level `AppBar`: `background.paper` surface, a
/// `borderBottom: 1 / divider`, a primary-colored 20px lucide `arrowLeft` back
/// button, an h6 (1.125rem = 18px, weight 600) title and optional trailing
/// actions (e.g. the 保存 button).
class ModelSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ModelSettingsAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      centerTitle: false,
      titleSpacing: 0,
      shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
        color: theme.colorScheme.primary,
        onPressed:
            onBack ??
            () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.defaultModelPath),
      ),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      title: Text(title),
      actions: actions,
    );
  }
}

/// The original inline `Paper`: `borderRadius: 2` (= 16px), a 1px
/// divider-colored border and a soft `0 4px 12px rgba(0,0,0,0.05)` shadow.
class ModelSettingsCard extends StatelessWidget {
  const ModelSettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A `subtitle1`-styled section heading (1rem = 16px, weight 600, text.primary)
/// — e.g. the card's 「API配置」 / 「提供商信息」 labels.
class ModelSectionTitle extends StatelessWidget {
  const ModelSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// A labelled outlined field: a `subtitle2` (0.875rem = 14px) `text.secondary`
/// label, an outlined `borderRadius: 2` (16px) small `TextField` and an
/// optional helper line. Data fields render disabled (greyed) this milestone.
class ModelFormField extends StatelessWidget {
  const ModelFormField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.controller,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A tonal toolbar/footer button — the original `Button` on a `borderRadius: 2`
/// (16px) low-alpha [accent] tint, weight 600, no text-transform. When
/// [onPressed] is null the action renders greyed (disabled), matching the
/// original's disabled state.
class ModelTonalButton extends StatelessWidget {
  const ModelTonalButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.accent,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final base = accent ?? theme.colorScheme.primary;
    final color = enabled ? base : theme.disabledColor;

    return Material(
      color: enabled
          ? base.withValues(alpha: 0.1)
          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
