part of 'settings_tab.dart';

/// Shared layout for a 设置 item (web `SettingItem`): title (+ 即将支持 chip) and an
/// optional description on the left, a [trailing] control on the right. When
/// [onTap] is set the whole row is tappable (used by the numeric rows).
class _SettingItemShell extends StatelessWidget {
  const _SettingItemShell({
    required this.title,
    required this.trailing,
    this.description,
    this.comingSoon = false,
    this.onTap,
  });

  final String title;
  final String? description;
  final Widget trailing;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const _ComingSoonChip(),
                    ],
                  ],
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A boolean 设置 item with a trailing [Switch].
class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      description: description,
      trailing: CustomSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// A 设置 item whose value is chosen from a dropdown of [options] `(value, 标签)`.
class _SelectSettingRow<T> extends StatelessWidget {
  const _SelectSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String description;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLabel =
        options.where((o) => o.$1 == value).firstOrNull?.$2 ?? '';
    return _SettingItemShell(
      title: title,
      description: description,
      comingSoon: comingSoon,
      trailing: PopupMenuButton<T>(
        popUpAnimationStyle: AnimationStyle.noAnimation,
        initialValue: value,
        onSelected: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        position: PopupMenuPosition.under,
        itemBuilder: (_) => [
          for (final (v, label) in options)
            PopupMenuItem<T>(value: v, child: Text(label)),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// A numeric 设置 item: shows the current value and opens a number prompt on tap.
class _NumberSettingRow extends StatelessWidget {
  const _NumberSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingItemShell(
      title: title,
      description: description,
      onTap: () async {
        final result = await _promptNumber(
          context,
          title: title,
          initial: value,
          min: min,
          max: max,
        );
        if (result != null) onChanged(result);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatInt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.pencil, size: 14, color: kSidebarMutedIcon),
        ],
      ),
    );
  }
}

/// A 设置 item rendered as a labelled slider over `[min, max]`.
class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.marks,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  /// Optional tick-mark labels keyed by their slider value (e.g.
  /// `{0: '0', 50: '50', 100: '最大'}`). When non-null a row of labels is
  /// rendered below the slider track, matching the original web UI.
  final Map<double, String>? marks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Text(
            description,
            style: TextStyle(fontSize: 11.5, height: 1.3, color: textSecondary),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
          if (marks != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final entry in marks!.entries)
                    Text(
                      entry.value,
                      style: TextStyle(fontSize: 10, color: textSecondary),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A read-only 设置 item: a label and a fixed value (e.g. 渲染引擎).
class _StaticSettingRow extends StatelessWidget {
  const _StaticSettingRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The amber 即将支持 badge. Re-declared here (rather than reusing the settings
/// feature's chip) because the chat feature must not import another feature's
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1FFFA000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66FFA000)),
      ),
      child: const Text(
        '即将支持',
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: Color(0xFFB07400),
        ),
      ),
    );
  }
}

/// Prompts for an integer in `[min, max]`, returning the clamped value or null
/// on 取消.
Future<int?> _promptNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  final controller = TextEditingController(text: initial.toString());
  int? read() {
    final parsed = int.tryParse(controller.text.trim());
    if (parsed == null) return null;
    return parsed.clamp(min, max);
  }

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          helperText: '范围 ${_formatInt(min)} – ${_formatInt(max)}',
        ),
        onSubmitted: (_) => Navigator.of(dialogContext).pop(read()),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.of(dialogContext).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.of(dialogContext).pop(read());
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
