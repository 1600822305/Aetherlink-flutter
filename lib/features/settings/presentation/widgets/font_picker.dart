import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/application/font_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/font_settings.dart';

/// 字体维度：应用字体（全局界面文字）或代码字体（代码块 / 行内代码）。
enum FontDimension { app, code }

/// The 全局字体 block on the appearance page: an 应用字体 row over a 代码字体 row.
/// Each row opens [FontPickerSheet] to pick from 系统 / Google / 本地 sources,
/// mirroring the web product shape while staying fully Flutter-native.
class FontFamilySection extends ConsumerWidget {
  const FontFamilySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(fontSettingsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FontFieldRow(
          label: '应用字体',
          helper: '选择应用的全局字体，影响所有界面文字的显示效果',
          selection: settings.appFont,
          defaultLabel: '系统默认',
          dimension: FontDimension.app,
        ),
        const SizedBox(height: 16),
        _FontFieldRow(
          label: '代码字体',
          helper: '代码块与行内代码使用的等宽字体，独立于应用字体',
          selection: settings.codeFont,
          defaultLabel: '系统等宽',
          dimension: FontDimension.code,
        ),
      ],
    );
  }
}

String _sourceLabel(FontSource source) => switch (source) {
  FontSource.system => '系统',
  FontSource.google => 'Google',
  FontSource.local => '本地',
};

class _FontFieldRow extends ConsumerWidget {
  const _FontFieldRow({
    required this.label,
    required this.helper,
    required this.selection,
    required this.defaultLabel,
    required this.dimension,
  });

  final String label;
  final String helper;
  final FontSelection selection;
  final String defaultLabel;
  final FontDimension dimension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.dividerColor),
    );
    final hasFamily = selection.family.isNotEmpty;
    final value = hasFamily ? selection.family : defaultLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) =>
            FontPickerSheet(dimension: dimension, current: selection),
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          helperStyle: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          labelStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: border,
          enabledBorder: border,
          suffixIcon: Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (hasFamily)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _SourceTag(label: _sourceLabel(selection.source)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A modal bottom sheet to pick a font for one [FontDimension] from one of the
/// three sources (系统 / Google / 本地) or to reset to the platform default.
/// Selecting a font applies it immediately through [FontSettingsController].
class FontPickerSheet extends ConsumerStatefulWidget {
  const FontPickerSheet({
    required this.dimension,
    required this.current,
    super.key,
  });

  final FontDimension dimension;
  final FontSelection current;

  @override
  ConsumerState<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends ConsumerState<FontPickerSheet> {
  FontSource _source = FontSource.system;
  String _query = '';
  List<String> _system = const [];
  List<String> _google = const [];
  List<FontSelection> _local = const [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _source = widget.current.family.isEmpty
        ? FontSource.system
        : widget.current.source;
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(fontLoaderServiceProvider);
    final system = service.systemFonts();
    final google = service.googleFonts();
    final local = await service.localFonts();
    if (!mounted) return;
    setState(() {
      _system = system;
      _google = google;
      _local = local;
      _loading = false;
    });
  }

  bool get _isCode => widget.dimension == FontDimension.code;

  String get _title => _isCode ? '选择代码字体' : '选择应用字体';

  String get _defaultLabel => _isCode ? '系统等宽' : '系统默认';

  Future<void> _apply(FontSelection selection) async {
    final controller = ref.read(fontSettingsControllerProvider.notifier);
    if (_isCode) {
      await controller.setCodeFont(selection);
    } else {
      await controller.setAppFont(selection);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _importLocal() async {
    setState(() => _importing = true);
    final selection = await ref
        .read(fontLoaderServiceProvider)
        .importLocalFont();
    if (!mounted) return;
    setState(() => _importing = false);
    if (selection != null) await _apply(selection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          _SourceSelector(
            source: _source,
            onChanged: (s) => setState(() => _source = s),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索字体',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (_source == FontSource.local)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _importLocal,
                  icon: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.plus, size: 18),
                  label: const Text('添加本地字体'),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    final defaultSelected = widget.current.family.isEmpty;

    final List<FontSelection> options;
    switch (_source) {
      case FontSource.system:
        options = [
          for (final f in _system)
            FontSelection(source: FontSource.system, family: f),
        ];
      case FontSource.google:
        options = [
          for (final f in _google)
            FontSelection(source: FontSource.google, family: f),
        ];
      case FontSource.local:
        options = _local;
    }

    final filtered = _query.isEmpty
        ? options
        : options
              .where(
                (o) => o.family.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return ListView.builder(
      controller: scrollController,
      itemCount: filtered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _FontOptionTile(
            title: _defaultLabel,
            selected: defaultSelected,
            previewFamily: null,
            isCode: _isCode,
            onTap: () => _apply(const FontSelection()),
          );
        }
        final option = filtered[index - 1];
        final selected =
            !defaultSelected &&
            widget.current.source == option.source &&
            widget.current.family == option.family;
        return _FontOptionTile(
          title: option.family,
          selected: selected,
          previewFamily: _resolvePreview(option),
          isCode: _isCode,
          onTap: () => _apply(option),
        );
      },
    );
  }

  /// The family name to render the preview text with. Google fonts resolve via
  /// [GoogleFonts] (kicking off the lazy fetch); system / local fonts use the
  /// family name directly.
  String? _resolvePreview(FontSelection option) {
    if (option.source == FontSource.google) {
      try {
        return GoogleFonts.getFont(option.family).fontFamily;
      } catch (_) {
        return null;
      }
    }
    return option.family;
  }
}

class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.source, required this.onChanged});

  final FontSource source;
  final ValueChanged<FontSource> onChanged;

  static const List<(FontSource, String)> _items = [
    (FontSource.system, '系统'),
    (FontSource.google, 'Google'),
    (FontSource.local, '本地'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final (value, label) in _items)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: value == source
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == source
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FontOptionTile extends StatelessWidget {
  const _FontOptionTile({
    required this.title,
    required this.selected,
    required this.previewFamily,
    required this.isCode,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final String? previewFamily;
  final bool isCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = isCode ? 'const x = 42; // 代码 0Oo1Il' : 'Aa 字体预览 0123';
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: previewFamily,
          fontFamilyFallback: isCode ? const ['monospace'] : null,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: selected
          ? Icon(LucideIcons.check, size: 20, color: theme.colorScheme.primary)
          : null,
    );
  }
}
