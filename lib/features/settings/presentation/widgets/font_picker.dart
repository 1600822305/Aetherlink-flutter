import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/application/font_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/font_settings.dart';

/// 字体维度：应用字体（全局界面文字）或代码字体（代码块 / 行内代码）。
enum FontDimension { app, code }

/// The 全局字体 block on the appearance page: an 应用字体 row over a 代码字体 row.
/// Each row opens [FontPickerPage] to pick from 系统 / Google / 本地 sources,
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
      onTap: () => Navigator.of(context).push(
        _fastPickerRoute(
          FontPickerPage(dimension: dimension, current: selection),
        ),
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

/// A snappy push route for [FontPickerPage]: a brief fade + slide that avoids
/// the default `MaterialPageRoute`'s long forward/return transition lag.
PageRoute<void> _fastPickerRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A full-page picker for one [FontDimension]. Fonts can be chosen from one of
/// the three sources (系统 / Google / 本地) or reset to the platform default.
/// Google Fonts are additionally grouped / filtered by style category (无衬线 /
/// 衬线 / 等宽 / 展示 / 手写) and a 中文 filter for the families that ship CJK
/// glyphs, mirroring the original web product. Selecting a font applies it
/// immediately through [FontSettingsController].
class FontPickerPage extends ConsumerStatefulWidget {
  const FontPickerPage({
    required this.dimension,
    required this.current,
    super.key,
  });

  final FontDimension dimension;
  final FontSelection current;

  @override
  ConsumerState<FontPickerPage> createState() => _FontPickerPageState();
}

/// Google Fonts style categories (plus a synthetic 全部 / 中文) and their labels.
const String _kGfAll = 'all';
const String _kGfCjk = 'cjk';
const List<(String, String)> _kGfCategories = [
  (_kGfAll, '全部'),
  (_kGfCjk, '中文'),
  ('sans-serif', '无衬线'),
  ('serif', '衬线'),
  ('monospace', '等宽'),
  ('display', '展示'),
  ('handwriting', '手写'),
];

String _gfCategoryLabel(String category) {
  for (final (value, label) in _kGfCategories) {
    if (value == category) return label;
  }
  return category;
}

class _FontPickerPageState extends ConsumerState<FontPickerPage> {
  FontSource _source = FontSource.system;
  String _query = '';
  String _gfCategory = _kGfAll;
  List<String> _system = const [];
  List<GoogleFontInfo> _google = const [];
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
    final google = await service.googleFontsCategorized();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(_title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SourceSelector(
                source: _source,
                onChanged: (s) => setState(() => _source = s),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchField(
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            if (_source == FontSource.google) ...[
              const SizedBox(height: 10),
              _GfCategoryBar(
                selected: _gfCategory,
                onChanged: (c) => setState(() => _gfCategory = c),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '多数 Google 字体仅含拉丁字形，中文请选「中文」分类',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_source == FontSource.local)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ImportFontButton(
                  importing: _importing,
                  onPressed: _importing ? null : _importLocal,
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Flattens the current source / filter selection into a list of rows
  /// (a header or a font option), so a single `ListView.builder` can render
  /// grouped sections while staying virtualized.
  List<_PickerRow> _rows() {
    final rows = <_PickerRow>[const _OptionRow(null)];
    final q = _query.toLowerCase();
    bool matches(String family) =>
        q.isEmpty || family.toLowerCase().contains(q);

    switch (_source) {
      case FontSource.system:
        for (final f in _system) {
          if (matches(f)) {
            rows.add(
              _OptionRow(FontSelection(source: FontSource.system, family: f)),
            );
          }
        }
      case FontSource.local:
        for (final f in _local) {
          if (matches(f.family)) rows.add(_OptionRow(f));
        }
      case FontSource.google:
        _appendGoogleRows(rows, matches);
    }
    return rows;
  }

  void _appendGoogleRows(List<_PickerRow> rows, bool Function(String) matches) {
    final visible = [
      for (final info in _google)
        if (matches(info.family)) info,
    ];
    if (_gfCategory == _kGfCjk) {
      for (final info in visible) {
        if (info.cjk) rows.add(_OptionRow(info.toSelection()));
      }
      return;
    }
    if (_gfCategory != _kGfAll) {
      for (final info in visible) {
        if (info.category == _gfCategory) {
          rows.add(_OptionRow(info.toSelection()));
        }
      }
      return;
    }
    // 全部：group by style category, in the catalog's canonical order.
    for (final (value, _) in _kGfCategories) {
      if (value == _kGfAll || value == _kGfCjk) continue;
      final group = [
        for (final info in visible)
          if (info.category == value) info,
      ];
      if (group.isEmpty) continue;
      rows.add(_HeaderRow(_gfCategoryLabel(value)));
      for (final info in group) {
        rows.add(_OptionRow(info.toSelection()));
      }
    }
  }

  Widget _buildList() {
    final rows = _rows();
    final defaultSelected = widget.current.family.isEmpty;
    return _PickerCard(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is _HeaderRow) return _SectionHeader(label: row.label);
          final option = (row as _OptionRow).option;
          final showDivider =
              index < rows.length - 1 && rows[index + 1] is _OptionRow;
          if (option == null) {
            return _FontOptionTile(
              title: _defaultLabel,
              selected: defaultSelected,
              previewFamily: null,
              isCode: _isCode,
              showDivider: showDivider,
              onTap: () => _apply(const FontSelection()),
            );
          }
          final selected =
              !defaultSelected &&
              widget.current.source == option.source &&
              widget.current.family == option.family;
          return _FontOptionTile(
            title: option.family,
            selected: selected,
            previewFamily: _resolvePreview(option),
            isCode: _isCode,
            showDivider: showDivider,
            onTap: () => _apply(option),
          );
        },
      ),
    );
  }

  /// The family name to render the preview text with. System / local fonts use
  /// the family name directly (cheap — already registered). Google fonts are
  /// intentionally NOT resolved here: `GoogleFonts.getFont` kicks off a network
  /// fetch + registration per call, and doing that for every row that scrolls
  /// into view janks the list. Their preview falls back to the default font.
  String? _resolvePreview(FontSelection option) {
    if (option.source == FontSource.google) return null;
    return option.family;
  }
}

extension on GoogleFontInfo {
  FontSelection toSelection() =>
      FontSelection(source: FontSource.google, family: family);
}

/// A row in the picker list: either a category header or a font option (a null
/// option denotes the "platform default" reset tile).
sealed class _PickerRow {
  const _PickerRow();
}

class _HeaderRow extends _PickerRow {
  const _HeaderRow(this.label);
  final String label;
}

class _OptionRow extends _PickerRow {
  const _OptionRow(this.option);
  final FontSelection? option;
}

/// A card surface matching the appearance page's `_AppearanceCard`: a rounded,
/// divider-bordered container with a soft shadow, clipped so children honor the
/// corners. Used to host the font list so it reads like the rest of settings.
class _PickerCard extends StatelessWidget {
  const _PickerCard({required this.child});

  final Widget child;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: const Color(0x03000000),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The Google Fonts style filter, styled like the page's source selector: a
/// rounded bordered track of horizontally-scrollable tinted pills (matching
/// the segmented tab look used across settings).
class _GfCategoryBar extends StatelessWidget {
  const _GfCategoryBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kGfCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = _kGfCategories[index];
          final isSelected = value == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.transparent : theme.dividerColor,
                ),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
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

/// The page's search box, styled to match the settings forms: a filled,
/// rounded field with a borderless focus state and a leading search glyph.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        hintText: '搜索字体',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          LucideIcons.search,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// The "添加本地字体" action, styled as a full-width tinted iOS-style button
/// instead of a Material outlined button.
class _ImportFontButton extends StatelessWidget {
  const _ImportFontButton({required this.importing, required this.onPressed});

  final bool importing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (importing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  LucideIcons.plus,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Text(
                '添加本地字体',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
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
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final String? previewFamily;
  final bool isCode;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = isCode ? 'const x = 42; // 代码 0Oo1Il' : 'Aa 字体预览 0123';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: previewFamily,
                      fontFamilyFallback: isCode ? const ['monospace'] : null,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 12),
              Icon(
                LucideIcons.check,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
