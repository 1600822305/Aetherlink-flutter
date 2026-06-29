import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/restore_plan.dart';

/// Pre-restore selection → streamed progress → per-category reconciliation,
/// modelled on Cherry Studio v2's migration wizard but driven by the user's
/// own choices (分领域 + 对数校验 + 自选 + 流式).
///
/// Returns the [RestoreResult] when a restore ran, or null if the user
/// cancelled before starting.
class RestoreSelectionSheet extends StatefulWidget {
  const RestoreSelectionSheet({
    super.key,
    required this.controller,
    required this.scan,
    required this.filePath,
  });

  final BackupController controller;
  final BackupScan scan;
  final String filePath;

  static Future<RestoreResult?> show(
    BuildContext context, {
    required BackupController controller,
    required BackupScan scan,
    required String filePath,
  }) {
    return showModalBottomSheet<RestoreResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RestoreSelectionSheet(
        controller: controller,
        scan: scan,
        filePath: filePath,
      ),
    );
  }

  @override
  State<RestoreSelectionSheet> createState() => _RestoreSelectionSheetState();
}

enum _Phase { select, running, result }

class _RestoreSelectionSheetState extends State<RestoreSelectionSheet> {
  _Phase _phase = _Phase.select;
  RestoreMode _mode = RestoreMode.overwrite;
  late final Set<BackupCategory> _selected;

  RestoreProgress? _progress;
  RestoreResult? _result;

  @override
  void initState() {
    super.initState();
    _selected = widget.scan.presentCategories.toSet();
  }

  bool get _anySelected => _selected.isNotEmpty;

  /// Categories present in this backup, for filtering dependency links.
  late final Set<BackupCategory> _present =
      widget.scan.presentCategories.toSet();

  /// Toggles [c], keeping dependent categories consistent so an overwrite
  /// restore can't orphan child records:
  /// - checking a child also checks the parents it needs (messages→topics, …)
  /// - unchecking a parent also unchecks the children that depend on it.
  void _toggle(BackupCategory c, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(c);
        _selected.addAll(c.requiredAncestors.where(_present.contains));
      } else {
        _selected.remove(c);
        _selected.removeAll(c.dependentDescendants);
      }
    });
  }

  /// In overwrite mode, warn when a selected category's parent is missing from
  /// the backup (so its records can't be reattached and would be orphaned).
  bool get _hasOrphanRisk {
    if (_mode != RestoreMode.overwrite) return false;
    for (final c in _selected) {
      for (final dep in c.requiredAncestors) {
        if (_present.contains(dep) && !_selected.contains(dep)) return true;
      }
    }
    return false;
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.running;
      _progress = null;
    });
    final selection = RestoreSelection(categories: _selected, mode: _mode);
    final result = await widget.controller.restoreSelective(
      widget.filePath,
      selection,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _phase = _Phase.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // Block the system back button while a restore is streaming so the sheet
    // can't be dismissed mid-write (the DB transaction would keep running).
    return PopScope(
      canPop: _phase != _Phase.running,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: switch (_phase) {
            _Phase.select => _buildSelect(context),
            _Phase.running => _buildRunning(context),
            _Phase.result => _buildResult(context),
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 1: selection checklist
  // ---------------------------------------------------------------------------

  Widget _buildSelect(BuildContext context) {
    final theme = Theme.of(context);
    final present = widget.scan.presentCategories;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grabber(theme),
        _header(
          theme,
          title: '选择要导入的数据',
          subtitle: widget.scan.isWebFormat
              ? '来自 AetherLink Web 备份，共 ${widget.scan.totalRecords} 条记录'
              : '来自 Flutter 备份，共 ${widget.scan.totalRecords} 条记录',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              for (final c in present)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selected.contains(c),
                  onChanged: (v) => _toggle(c, v == true),
                  title: Text(c.label),
                  secondary: Text(
                    '${widget.scan.countOf(c)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (widget.scan.unsupported.isNotEmpty) ...[
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '以下数据 Flutter 暂不支持，将被忽略',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final u in widget.scan.unsupported)
                  ListTile(
                    dense: true,
                    enabled: false,
                    leading: Icon(
                      LucideIcons.ban,
                      size: 18,
                      color: theme.disabledColor,
                    ),
                    title: Text(u.name),
                    subtitle: Text(u.reason),
                    trailing: Text('${u.count}'),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('冲突处理', style: theme.textTheme.bodyMedium),
              const Spacer(),
              SegmentedButton<RestoreMode>(
                segments: const [
                  ButtonSegment(
                    value: RestoreMode.overwrite,
                    label: Text('覆盖'),
                  ),
                  ButtonSegment(value: RestoreMode.merge, label: Text('合并')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ),
        ),
        if (_hasOrphanRisk)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '所选数据的关联上级未一并导入，覆盖后可能产生无法关联的记录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _anySelected ? _start : null,
                  child: Text(
                    _mode == RestoreMode.overwrite ? '覆盖导入' : '合并导入',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 2: streamed progress
  // ---------------------------------------------------------------------------

  Widget _buildRunning(BuildContext context) {
    final theme = Theme.of(context);
    final p = _progress;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('正在导入…', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          Text(
            p == null ? '准备中' : '${p.category.label}（${p.done}/${p.total}）',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p?.fraction,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在分领域写入并校验，请勿关闭页面',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 3: per-category reconciliation
  // ---------------------------------------------------------------------------

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final entries = result?.byCategory.entries.toList() ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _grabber(theme),
        _header(
          theme,
          title: result == null
              ? '导入失败'
              : (result.reconciled ? '导入完成' : '导入完成（部分未对齐）'),
          subtitle: result?.summary ?? '请重试或检查备份文件',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              for (final e in entries) _resultRow(theme, e.key, e.value),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, result),
              child: const Text('完成'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultRow(ThemeData theme, BackupCategory c, CategoryStat s) {
    final ok = s.reconciled;
    final detail = StringBuffer('源 ${s.source} · 写入 ${s.target}');
    if (s.skipped > 0) detail.write(' · 跳过 ${s.skipped}');
    if (s.failed > 0) detail.write(' · 失败 ${s.failed}');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
        size: 18,
        color: ok ? Colors.green : theme.colorScheme.error,
      ),
      title: Text(c.label),
      subtitle: Text(detail.toString()),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared chrome
  // ---------------------------------------------------------------------------

  Widget _grabber(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4),
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header(
    ThemeData theme, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
