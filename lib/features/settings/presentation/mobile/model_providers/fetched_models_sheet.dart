import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_providers/provider_config_utils.dart';

/// Result of the [FetchedModelsSheet] — carries both the models to add and
/// the IDs to remove, supporting the full Web-version toggle behaviour.
class FetchedModelsResult {
  const FetchedModelsResult({required this.toAdd, required this.toRemove});

  /// Models the user newly selected for addition.
  final List<LlmModelInfo> toAdd;

  /// IDs of previously-existing models the user toggled off for removal.
  final List<String> toRemove;
}

/// Full-featured bottom sheet for selecting fetched models from the API.
///
/// Mirrors the Web version's `ModelManagementDrawer.solid.tsx`:
/// - Search/filter bar
/// - Grouped by model name prefix (collapsible)
/// - Per-group batch add/remove
/// - Per-model toggle (already-added can be toggled off for removal)
/// - Count badge in header
class FetchedModelsSheet extends StatefulWidget {
  const FetchedModelsSheet({
    super.key,
    required this.models,
    required this.existingIds,
    required this.providerId,
  });

  final List<LlmModelInfo> models;
  final Set<String> existingIds;
  final String providerId;

  @override
  State<FetchedModelsSheet> createState() => _FetchedModelsSheetState();
}

class _FetchedModelsSheetState extends State<FetchedModelsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  late final Set<String> _selected;
  late final Set<String> _removed;
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    // Default: select all models that are NOT already added
    _selected = {
      for (final m in widget.models)
        if (!widget.existingIds.contains(m.id)) m.id,
    };
    _removed = {};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Group models by their derived group name, filtered by search term.
  List<(String, List<LlmModelInfo>)> get _groupedModels {
    final searchLower = _searchTerm.toLowerCase();
    final groups = <String, List<LlmModelInfo>>{};

    for (final model in widget.models) {
      final name = model.name ?? model.id;
      if (searchLower.isNotEmpty &&
          !name.toLowerCase().contains(searchLower) &&
          !model.id.toLowerCase().contains(searchLower)) {
        continue;
      }
      final group = getDefaultGroupName(model.id, widget.providerId);
      groups.putIfAbsent(group, () => []).add(model);
    }

    final names = groups.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    return [for (final name in names) (name, groups[name]!)];
  }

  bool _isModelSelected(String id) {
    if (_removed.contains(id)) return false;
    return widget.existingIds.contains(id) || _selected.contains(id);
  }

  bool _isGroupFullySelected(List<LlmModelInfo> models) =>
      models.every((m) => _isModelSelected(m.id));

  int get _newSelectionCount =>
      _selected.where((id) => !widget.existingIds.contains(id)).length;

  int get _removeCount => _removed.length;

  bool get _hasChanges => _newSelectionCount > 0 || _removeCount > 0;

  void _toggleModel(String id) {
    setState(() {
      if (widget.existingIds.contains(id)) {
        // Toggle removal of an existing model
        if (_removed.contains(id)) {
          _removed.remove(id);
        } else {
          _removed.add(id);
        }
      } else {
        // Toggle selection of a new model
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      }
    });
  }

  void _toggleGroup(List<LlmModelInfo> models) {
    final allSelected = _isGroupFullySelected(models);
    setState(() {
      for (final m in models) {
        if (widget.existingIds.contains(m.id)) {
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
      if (_expandedGroups.contains(groupName)) {
        _expandedGroups.remove(groupName);
      } else {
        _expandedGroups.add(groupName);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final m in widget.models) {
        if (!widget.existingIds.contains(m.id)) {
          _selected.add(m.id);
        }
      }
      _removed.clear();
    });
  }

  void _deselectAll() {
    setState(() {
      _selected.removeWhere((id) => !widget.existingIds.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final grouped = _groupedModels;
    final totalCount = widget.models.length;

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
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ─── Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '获取到 $totalCount 个模型',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Select all / Deselect all
                    TextButton(
                      onPressed: _newSelectionCount ==
                              (totalCount - widget.existingIds.length)
                          ? _deselectAll
                          : _selectAll,
                      child: Text(
                        _newSelectionCount ==
                                (totalCount - widget.existingIds.length)
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),

              // ─── Search bar ───────────────────────────────────
              Padding(
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
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ─── Model groups list ────────────────────────────
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
                            isExpanded: _expandedGroups.contains(groupName),
                            isFullySelected: _isGroupFullySelected(models),
                            isModelSelected: _isModelSelected,
                            onToggleExpand: () => _toggleExpand(groupName),
                            onToggleGroup: () => _toggleGroup(models),
                            onToggleModel: _toggleModel,
                          );
                        },
                      ),
              ),

              // ─── Bottom action button ─────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: !_hasChanges
                          ? null
                          : () {
                              final toAdd = [
                                for (final m in widget.models)
                                  if (_selected.contains(m.id) &&
                                      !widget.existingIds.contains(m.id))
                                    m,
                              ];
                              final toRemove = _removed.toList();
                              Navigator.of(context).pop(
                                FetchedModelsResult(
                                  toAdd: toAdd,
                                  toRemove: toRemove,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildButtonLabel() {
    final parts = <String>[];
    if (_newSelectionCount > 0) parts.add('添加 $_newSelectionCount');
    if (_removeCount > 0) parts.add('移除 $_removeCount');
    return parts.isEmpty ? '确认' : parts.join(' · ');
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
    required this.onToggleExpand,
    required this.onToggleGroup,
    required this.onToggleModel,
  });

  final String groupName;
  final List<LlmModelInfo> models;
  final bool isExpanded;
  final bool isFullySelected;
  final bool Function(String) isModelSelected;
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
    final color = isFullySelected
        ? colorScheme.error
        : colorScheme.primary;

    return Material(
      color: color.withOpacity(0.1),
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
    required this.onToggle,
  });

  final LlmModelInfo model;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = model.name ?? model.id;
    final showId = name != model.id;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            // Model info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showId)
                    Text(
                      model.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status indicator — all models use the same selection indicator;
            // existing models that are still "kept" show as selected (green),
            // toggled-off existing models show as unselected (empty border).
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
          color: colorScheme.outline.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
