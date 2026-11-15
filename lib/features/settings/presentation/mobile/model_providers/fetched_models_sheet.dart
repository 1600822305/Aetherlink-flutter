import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_enricher.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_registry.dart';

/// Result of the [FetchedModelsSheet] — carries both the models to add and
/// the IDs to remove.
class FetchedModelsResult {
  const FetchedModelsResult({required this.toAdd, required this.toRemove});

  /// Models the user newly selected for addition.
  final List<LlmModelInfo> toAdd;

  /// IDs of previously-existing models the user toggled off for removal.
  final List<String> toRemove;
}

/// Bottom sheet for picking which fetched models to add (and which existing
/// ones to drop).
///
/// Design goals (more humane than "pre-check everything"):
///  * **Nothing is pre-selected** — fetching a provider with hundreds of models
///    no longer arms a bulk add; the user opts in per model / per group / via
///    「全选」.
///  * Already-added models are clearly tagged 「已添加」 and shown as kept; tapping
///    one marks it for removal.
///  * Each row shows the model's capability icons (vision / reasoning / tools /
///    web-search / embedding / rerank) so you know what you're adding.
///  * Grouped by series (collapsible), with per-group add/remove and search.
class FetchedModelsSheet extends StatefulWidget {
  const FetchedModelsSheet({
    super.key,
    required this.modelsFuture,
    required this.existingIds,
    required this.providerId,
  });

  /// The in-flight model fetch. The sheet opens immediately and shows a loading
  /// state while this resolves, so tapping 获取 has no perceived lag.
  final Future<List<LlmModelInfo>> modelsFuture;
  final Set<String> existingIds;
  final String providerId;

  @override
  State<FetchedModelsSheet> createState() => _FetchedModelsSheetState();
}

class _FetchedModelsSheetState extends State<FetchedModelsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  /// New (not-yet-added) model ids the user picked for addition.
  final Set<String> _selected = {};

  /// Already-added model ids the user toggled off for removal.
  final Set<String> _removed = {};

  final Set<String> _expandedGroups = {};
  final Map<String, ModelCapabilities?> _capsCache = {};

  List<LlmModelInfo> _models = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final models = await widget.modelsFuture;
      // Preset registry powers accurate capability icons; inference still works
      // without it, so don't fail the sheet if this throws.
      try {
        await ModelRegistry.instance.ensureLoaded();
      } catch (_) {}
      if (!mounted) return;
      // Intentionally NO default selection — the user opts in.
      setState(() {
        _models = models;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isExisting(String id) => widget.existingIds.contains(id);

  ModelCapabilities? _capsFor(String id) =>
      _capsCache.putIfAbsent(id, () => detectCapabilities(id));

  /// Group models by their derived group name, filtered by search term.
  List<(String, List<LlmModelInfo>)> get _groupedModels {
    final searchLower = _searchTerm.toLowerCase();
    final groups = <String, List<LlmModelInfo>>{};

    for (final model in _models) {
      final name = model.name ?? model.id;
      if (searchLower.isNotEmpty &&
          !name.toLowerCase().contains(searchLower) &&
          !model.id.toLowerCase().contains(searchLower)) {
        continue;
      }
      final group = getDefaultGroupName(model.id, widget.providerId);
      groups.putIfAbsent(group, () => []).add(model);
    }

    final names = groups.keys.toList()..sort((a, b) => a.compareTo(b));
    return [for (final name in names) (name, groups[name]!)];
  }

  /// Whether [id] will be present after applying the current selection: a kept
  /// existing model, or a newly-picked one.
  bool _isModelSelected(String id) {
    if (_removed.contains(id)) return false;
    return _isExisting(id) || _selected.contains(id);
  }

  bool _isGroupFullySelected(List<LlmModelInfo> models) =>
      models.every((m) => _isModelSelected(m.id));

  int get _newSelectionCount => _selected.length;
  int get _removeCount => _removed.length;
  bool get _hasChanges => _newSelectionCount > 0 || _removeCount > 0;

  int get _existingCount => _models.where((m) => _isExisting(m.id)).length;
  int get _newAvailableCount => _models.length - _existingCount;

  void _toggleModel(String id) {
    setState(() {
      if (_isExisting(id)) {
        if (!_removed.remove(id)) _removed.add(id);
      } else {
        if (!_selected.remove(id)) _selected.add(id);
      }
    });
  }

  void _toggleGroup(List<LlmModelInfo> models) {
    final allSelected = _isGroupFullySelected(models);
    setState(() {
      for (final m in models) {
        if (_isExisting(m.id)) {
          if (allSelected) {
            _removed.add(m.id);
          } else {
            _removed.remove(m.id);
          }
        } else {
          if (allSelected) {
            _selected.remove(m.id);
          } else {
            _selected.add(m.id);
          }
        }
      }
    });
  }

  void _toggleExpand(String groupName) {
    setState(() {
      if (!_expandedGroups.remove(groupName)) _expandedGroups.add(groupName);
    });
  }

  void _selectAllNew() {
    setState(() {
      for (final m in _models) {
        if (!_isExisting(m.id)) _selected.add(m.id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _removed.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final grouped = _groupedModels;
    // Auto-expand while searching or when there's a single group, so results
    // aren't hidden behind collapsed headers.
    final autoExpand = _searchTerm.isNotEmpty || grouped.length == 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ─── Drag handle ──────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(child: _buildErrorState(theme, colorScheme))
              else ...[
                _buildHeader(theme, colorScheme),
                _buildSearchBar(colorScheme),
                const SizedBox(height: 4),
                Expanded(
                  child: grouped.isEmpty
                      ? Center(
                          child: Text(
                            _searchTerm.isNotEmpty ? '未找到匹配的模型' : '暂无可用模型',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final (groupName, models) = grouped[index];
                            return _GroupSection(
                              groupName: groupName,
                              models: models,
                              isExpanded:
                                  autoExpand ||
                                  _expandedGroups.contains(groupName),
                              isFullySelected: _isGroupFullySelected(models),
                              isModelSelected: _isModelSelected,
                              isExisting: _isExisting,
                              capsFor: _capsFor,
                              onToggleExpand: () => _toggleExpand(groupName),
                              onToggleGroup: () => _toggleGroup(models),
                              onToggleModel: _toggleModel,
                            );
                          },
                        ),
                ),
                _buildFooter(colorScheme),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    final allNewSelected =
        _newAvailableCount > 0 && _newSelectionCount >= _newAvailableCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '获取到 ${_models.length} 个模型',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '已添加 $_existingCount · 可新增 $_newAvailableCount',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_newAvailableCount > 0)
            TextButton(
              onPressed: allNewSelected ? null : _selectAllNew,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('全选'),
            ),
          if (_hasChanges)
            TextButton(
              onPressed: _clearSelection,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              child: const Text('清空'),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchTerm = v),
        decoration: InputDecoration(
          hintText: '搜索模型...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchTerm = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: !_hasChanges
                    ? null
                    : () {
                        final toAdd = [
                          for (final m in _models)
                            if (_selected.contains(m.id) && !_isExisting(m.id))
                              m,
                        ];
                        Navigator.of(context).pop(
                          FetchedModelsResult(
                            toAdd: toAdd,
                            toRemove: _removed.toList(),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _buildButtonLabel(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            '获取模型失败，请检查密钥与基础 URL',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _buildButtonLabel() {
    final parts = <String>[];
    if (_newSelectionCount > 0) parts.add('添加 $_newSelectionCount');
    if (_removeCount > 0) parts.add('移除 $_removeCount');
    return parts.isEmpty ? '未选择' : parts.join(' · ');
  }
}

// ─── Group Section Widget ──────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.groupName,
    required this.models,
    required this.isExpanded,
    required this.isFullySelected,
    required this.isModelSelected,
    required this.isExisting,
    required this.capsFor,
    required this.onToggleExpand,
    required this.onToggleGroup,
    required this.onToggleModel,
  });

  final String groupName;
  final List<LlmModelInfo> models;
  final bool isExpanded;
  final bool isFullySelected;
  final bool Function(String) isModelSelected;
  final bool Function(String) isExisting;
  final ModelCapabilities? Function(String) capsFor;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleGroup;
  final ValueChanged<String> onToggleModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Group header
        InkWell(
          onTap: onToggleExpand,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: groupName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' (${models.length})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Group batch toggle button
                _GroupActionButton(
                  isFullySelected: isFullySelected,
                  onTap: onToggleGroup,
                ),
              ],
            ),
          ),
        ),

        // Expanded model list
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final model in models)
                  _ModelItem(
                    model: model,
                    isSelected: isModelSelected(model.id),
                    isExisting: isExisting(model.id),
                    caps: capsFor(model.id),
                    onToggle: () => onToggleModel(model.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Group Action Button ───────────────────────────────────────────────────

class _GroupActionButton extends StatelessWidget {
  const _GroupActionButton({
    required this.isFullySelected,
    required this.onTap,
  });

  final bool isFullySelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isFullySelected ? colorScheme.error : colorScheme.primary;

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isFullySelected ? Icons.remove : Icons.add,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Model Item Widget ─────────────────────────────────────────────────────

class _ModelItem extends StatelessWidget {
  const _ModelItem({
    required this.model,
    required this.isSelected,
    required this.isExisting,
    required this.caps,
    required this.onToggle,
  });

  final LlmModelInfo model;
  final bool isSelected;
  final bool isExisting;
  final ModelCapabilities? caps;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = model.name ?? model.id;
    final showId = name != model.id;
    final dim = !isSelected;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: dim
                                ? colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  )
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isExisting) ...[
                        const SizedBox(width: 6),
                        _Pill(label: '已添加', color: colorScheme.primary),
                      ],
                    ],
                  ),
                  if (showId)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        model.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (caps != null) ...[
                    const SizedBox(height: 4),
                    _CapabilityStrip(caps: caps!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SelectionIndicator(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}

// ─── Selection Indicator ───────────────────────────────────────────────────

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isSelected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

// ─── Small pill tag ────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Capability icons (Cherry-style) ───────────────────────────────────────

/// A compact, read-only strip of capability icons inferred from a model id.
/// Icon set / colours match Cherry Studio's per-row capability tags.
class _CapabilityStrip extends StatelessWidget {
  const _CapabilityStrip({required this.caps});

  final ModelCapabilities caps;

  @override
  Widget build(BuildContext context) {
    final badges = <(IconData, Color, String)>[
      if (caps.vision == true || caps.multimodal == true)
        (LucideIcons.eye, const Color(0xFF00B96B), '视觉'),
      if (caps.webSearch == true)
        (LucideIcons.globe, const Color(0xFF1677FF), '网络搜索'),
      if (caps.reasoning == true)
        (LucideIcons.lightbulb, const Color(0xFF6372BD), '推理'),
      if (caps.functionCalling == true || caps.toolUse == true)
        (LucideIcons.wrench, const Color(0xFFF18737), '函数调用'),
      if (caps.imageGeneration == true)
        (LucideIcons.image, const Color(0xFFA855F7), '图像生成'),
      if (caps.videoGeneration == true)
        (LucideIcons.video, const Color(0xFFEC4899), '视频生成'),
      if (caps.embedding == true)
        (LucideIcons.code2, const Color(0xFFFFA500), '嵌入'),
      if (caps.rerank == true)
        (LucideIcons.rotateCw, const Color(0xFF6495ED), '重排序'),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icon, color, label) in badges)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Tooltip(
              message: label,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.125),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 11, color: color),
              ),
            ),
          ),
      ],
    );
  }
}
