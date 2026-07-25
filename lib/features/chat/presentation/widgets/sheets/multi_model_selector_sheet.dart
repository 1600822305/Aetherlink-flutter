import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// Opens the 多模型发送 picker: a multi-select sheet listing every chat model
/// grouped by provider with checkboxes. Returns the chosen `(provider, model)`
/// pairs on 确定, or `null` if dismissed/cancelled. [initial] pre-checks the
/// currently-staged mentions so re-opening the sheet edits the selection.
Future<List<CurrentModel>?> showMultiModelSelectorSheet(
  BuildContext context, {
  List<CurrentModel> initial = const <CurrentModel>[],
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<List<CurrentModel>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _MultiModelSelectorSheet(initial: initial),
  );
}

class _MultiModelSelectorSheet extends ConsumerStatefulWidget {
  const _MultiModelSelectorSheet({required this.initial});

  final List<CurrentModel> initial;

  @override
  ConsumerState<_MultiModelSelectorSheet> createState() =>
      _MultiModelSelectorSheetState();
}

class _MultiModelSelectorSheetState
    extends ConsumerState<_MultiModelSelectorSheet> {
  /// Selected models keyed by `providerId\u0000modelId` for stable identity.
  late final Set<String> _selected = {
    for (final m in widget.initial) _key(m.provider.id, m.model.id),
  };

  static String _key(String providerId, String modelId) =>
      '$providerId\u0000$modelId';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(appModelProvidersProvider);
    // Only enabled providers are offered, matching web `useModelSelection`'s
    // `provider.isEnabled` gate.
    final providers = [
      for (final p in providersAsync.value ?? const <ModelProvider>[])
        if (p.isEnabled) p,
    ];
    final mq = MediaQuery.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '多模型发送',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Text(
                      '已选 ${_selected.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: providersAsync.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        for (final provider in providers)
                          ..._providerSection(theme, provider),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _confirm(providers),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _providerSection(ThemeData theme, ModelProvider provider) {
    final models = [
      for (final m in provider.models)
        if (!isNonChatModel(m)) m,
    ];
    if (models.isEmpty) return const <Widget>[];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          provider.name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final model in models) _modelTile(theme, provider, model),
    ];
  }

  Widget _modelTile(ThemeData theme, ModelProvider provider, Model model) {
    final key = _key(provider.id, model.id);
    final checked = _selected.contains(key);
    return CheckboxListTile(
      value: checked,
      onChanged: (_) => setState(() {
        if (checked) {
          _selected.remove(key);
        } else {
          _selected.add(key);
        }
      }),
      controlAffinity: ListTileControlAffinity.trailing,
      dense: true,
      secondary: _ModelIcon(provider: provider, model: model),
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  void _confirm(List<ModelProvider> providers) {
    final chosen = <CurrentModel>[];
    // Preserve provider→model listing order for a stable comparison layout.
    for (final provider in providers) {
      for (final model in provider.models) {
        if (_selected.contains(_key(provider.id, model.id))) {
          chosen.add(CurrentModel(provider: provider, model: model));
        }
      }
    }
    Navigator.of(context).pop(chosen);
  }
}

/// A 28×28 provider/model icon with a first-letter fallback (mirrors the chat
/// model selector's `_ProviderIcon`).
class _ModelIcon extends StatelessWidget {
  const _ModelIcon({required this.provider, required this.model});

  final ModelProvider provider;
  final Model model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final providerId = model.provider.isNotEmpty ? model.provider : provider.id;
    final asset = getModelOrProviderIcon(model.id, providerId, isDark: isDark);
    return SizedBox(
      width: 28,
      height: 28,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          asset,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              provider.name.isNotEmpty ? provider.name.characters.first : '?',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ),
    );
  }
}
