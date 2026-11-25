// 条目编辑页（全屏子页，零时长路由）。按「写什么 → 什么时候注入 → 注入到哪里
// → 高级」组织：
//   · 内容：名称 + 设定内容（带字数）；
//   · 触发：分段选择「出现关键词时 / 总是（常驻）」，关键词模式下给关键词框、
//     匹配选项与扫描深度；
//   · 注入：位置 chips + 一句说明，按位置显示角色 / 深度；
//   · 高级（可折叠，有非默认值时默认展开）：优先级与 sticky / cooldown / delay。
// 有未保存修改时返回会二次确认；编辑已有条目时页底可删除。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_form_sections.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 打开条目编辑页；[entry] 为 null 表示新建。
Future<void> showWorldBookEntryEditPage(
  BuildContext context, {
  required String bookId,
  WorldBookEntry? entry,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) =>
          WorldBookEntryEditPage(bookId: bookId, entry: entry),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class WorldBookEntryEditPage extends ConsumerStatefulWidget {
  const WorldBookEntryEditPage({super.key, required this.bookId, this.entry});

  final String bookId;
  final WorldBookEntry? entry;

  @override
  ConsumerState<WorldBookEntryEditPage> createState() =>
      _WorldBookEntryEditPageState();
}

class _WorldBookEntryEditPageState
    extends ConsumerState<WorldBookEntryEditPage> {
  late final WorldBookEntry _base = widget.entry ?? const WorldBookEntry(id: '');
  late final TextEditingController _name = TextEditingController(
    text: _base.name,
  );
  late final TextEditingController _content = TextEditingController(
    text: _base.content,
  );
  late final TextEditingController _priority = _number(_base.priority);
  late final TextEditingController _scanDepth = _number(_base.scanDepth);
  late final TextEditingController _injectDepth = _number(_base.injectDepth);
  late final TextEditingController _sticky = _number(_base.sticky);
  late final TextEditingController _cooldown = _number(_base.cooldown);
  late final TextEditingController _delay = _number(_base.delay);

  late List<String> _keywords = List.of(_base.keywords);
  late bool _useRegex = _base.useRegex;
  late bool _caseSensitive = _base.caseSensitive;
  late bool _constantActive = _base.constantActive;
  late WorldBookInjectionPosition _position = _base.position;
  late WorldBookInjectionRole _role = _base.role;

  /// 高级项有非默认值时默认展开，避免用户看不到已设置的计时器。
  late bool _advancedOpen =
      _base.priority != 0 ||
      _base.sticky != 0 ||
      _base.cooldown != 0 ||
      _base.delay != 0;

  bool _saving = false;

  bool get _isNew => widget.entry == null;

  static TextEditingController _number(int value) =>
      TextEditingController(text: value.toString());

  @override
  void initState() {
    super.initState();
    // 内容字数实时刷新。
    _content.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _content.removeListener(_refresh);
    for (final c in [
      _name,
      _content,
      _priority,
      _scanDepth,
      _injectDepth,
      _sticky,
      _cooldown,
      _delay,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c, int fallback, int min, int max) =>
      (int.tryParse(c.text.trim()) ?? fallback).clamp(min, max);

  WorldBookEntry _collect() => _base.copyWith(
    name: _name.text.trim(),
    content: _content.text,
    keywords: _keywords,
    useRegex: _useRegex,
    caseSensitive: _caseSensitive,
    constantActive: _constantActive,
    position: _position,
    role: _role,
    priority: _read(_priority, _base.priority, -1000000, 1000000),
    scanDepth: _read(_scanDepth, 4, 1, WorldBookEntry.kMaxDepth),
    injectDepth: _read(_injectDepth, 4, 0, WorldBookEntry.kMaxDepth),
    sticky: _read(_sticky, 0, 0, WorldBookEntry.kMaxTimerValue),
    cooldown: _read(_cooldown, 0, 0, WorldBookEntry.kMaxTimerValue),
    delay: _read(_delay, 0, 0, WorldBookEntry.kMaxTimerValue),
  );

  bool get _dirty => _collect() != _base;

  bool get _canSave =>
      !_saving &&
      (_name.text.trim().isNotEmpty || _content.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(worldBooksControllerProvider.notifier)
          .saveEntry(widget.bookId, _collect());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final ok = await confirmWorldBookAction(
      context,
      title: '删除条目',
      message: '将删除「${entry.name.isEmpty ? '未命名条目' : entry.name}」。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(worldBooksControllerProvider.notifier)
        .deleteEntry(widget.bookId, entry.id);
    if (!mounted) return;
    AppToast.success(context, '已删除条目');
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmWorldBookAction(
      context,
      title: '放弃修改？',
      message: '这个条目有未保存的修改，返回后会丢失。',
      confirmLabel: '放弃',
      destructive: true,
    );
  }

  Future<void> _back() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  // ───────────────────────── sections ─────────────────────────

  Widget _card(List<Widget> children, {EdgeInsets? padding}) =>
      WorldBookOutlinedCard(
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  Widget _divider() => Divider(height: 1, color: Theme.of(context).dividerColor);

  Widget _contentCard(ThemeData theme) {
    final length = _content.text.characters.length;
    return _card([
      TextField(
        controller: _name,
        autofocus: _isNew,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        style: theme.textTheme.titleSmall?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          labelText: '条目名称',
          hintText: '如：外貌、王都、魔法规则',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _content,
        minLines: 5,
        maxLines: 14,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        decoration: const InputDecoration(
          labelText: '设定内容',
          hintText: '触发时注入给模型的文本',
          alignLabelWithHint: true,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '$length 字',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ]);
  }

  Widget _triggerCard() {
    return _card([
      WorldBookSegmented<bool>(
        options: const [(false, '出现关键词时'), (true, '总是（常驻）')],
        value: _constantActive,
        onChanged: (v) => setState(() => _constantActive = v),
      ),
      if (_constantActive)
        const WorldBookInlineNote('每次对话都会注入这段内容，会持续占用上下文。')
      else ...[
        const WorldBookFieldLabel('关键词'),
        WorldBookKeywordsField(
          keywords: _keywords,
          useRegex: _useRegex,
          onChanged: (v) => setState(() => _keywords = v),
        ),
        if (_keywords.isEmpty)
          const WorldBookInlineNote('还没有关键词，这个条目不会被触发。', warning: true),
        const SizedBox(height: 4),
        WorldBookSwitchRow(
          title: '正则表达式',
          subtitle: '把每个关键词当作正则匹配',
          value: _useRegex,
          onChanged: (v) => setState(() => _useRegex = v),
        ),
        _divider(),
        WorldBookSwitchRow(
          title: '区分大小写',
          value: _caseSensitive,
          onChanged: (v) => setState(() => _caseSensitive = v),
        ),
        _divider(),
        WorldBookNumberRow(
          controller: _scanDepth,
          title: '扫描深度',
          subtitle: '在最近多少条消息里找关键词',
          min: 1,
          max: WorldBookEntry.kMaxDepth,
          onChanged: _refresh,
        ),
      ],
    ]);
  }

  bool get _usesRole =>
      _position == WorldBookInjectionPosition.topOfChat ||
      _position == WorldBookInjectionPosition.bottomOfChat ||
      _position == WorldBookInjectionPosition.atDepth;

  Widget _injectionCard() {
    return _card([
      WorldBookPositionSelector(
        value: _position,
        onChanged: (v) => setState(() => _position = v),
      ),
      WorldBookInlineNote(worldBookPositionHint(_position)),
      if (_position == WorldBookInjectionPosition.atDepth) ...[
        const SizedBox(height: 4),
        WorldBookNumberRow(
          controller: _injectDepth,
          title: '注入深度',
          subtitle: '0 = 最后一条消息之后，1 = 它之前',
          min: 0,
          max: WorldBookEntry.kMaxDepth,
          onChanged: _refresh,
        ),
      ],
      if (_usesRole) ...[
        const WorldBookFieldLabel('以谁的身份插入'),
        WorldBookSegmented<WorldBookInjectionRole>(
          options: const [
            (WorldBookInjectionRole.user, '用户'),
            (WorldBookInjectionRole.assistant, '助手'),
          ],
          value: _role,
          onChanged: (v) => setState(() => _role = v),
        ),
      ],
    ]);
  }

  String _advancedSummary() {
    final p = _read(_priority, 0, -1000000, 1000000);
    final s = _read(_sticky, 0, 0, WorldBookEntry.kMaxTimerValue);
    final c = _read(_cooldown, 0, 0, WorldBookEntry.kMaxTimerValue);
    final d = _read(_delay, 0, 0, WorldBookEntry.kMaxTimerValue);
    if (p == 0 && s == 0 && c == 0 && d == 0) return '默认';
    return [
      if (p != 0) '优先级 $p',
      if (s != 0) '持续 $s',
      if (c != 0) '冷却 $c',
      if (d != 0) '延迟 $d',
    ].join(' · ');
  }

  Widget _advancedCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return WorldBookOutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '优先级与计时器',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _advancedSummary(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _advancedOpen
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
          if (_advancedOpen) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Column(
                children: [
                  WorldBookNumberRow(
                    controller: _priority,
                    title: '优先级',
                    subtitle: '越大越靠前注入，可为负',
                    min: -1000000,
                    max: 1000000,
                    onChanged: _refresh,
                  ),
                  _divider(),
                  WorldBookNumberRow(
                    controller: _sticky,
                    title: '持续',
                    subtitle: '触发后继续生效的消息数',
                    min: 0,
                    max: WorldBookEntry.kMaxTimerValue,
                    onChanged: _refresh,
                  ),
                  _divider(),
                  WorldBookNumberRow(
                    controller: _cooldown,
                    title: '冷却',
                    subtitle: '持续结束后多少条消息内不再触发',
                    min: 0,
                    max: WorldBookEntry.kMaxTimerValue,
                    onChanged: _refresh,
                  ),
                  _divider(),
                  WorldBookNumberRow(
                    controller: _delay,
                    title: '延迟',
                    subtitle: '对话满多少条消息后才可触发',
                    min: 0,
                    max: WorldBookEntry.kMaxTimerValue,
                    onChanged: _refresh,
                  ),
                  const WorldBookInlineNote('计时器都按消息条数计算，0 表示关闭。'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: buildWorldBookAppBar(
          context,
          title: _isNew ? '新建条目' : '编辑条目',
          onBack: _back,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _contentCard(theme),
              const WorldBookFormLabel('什么时候注入'),
              _triggerCard(),
              const WorldBookFormLabel('注入到哪里'),
              _injectionCard(),
              const WorldBookFormLabel('高级'),
              _advancedCard(theme),
              if (!_isNew) ...[
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                      textStyle: theme.textTheme.bodySmall,
                    ),
                    onPressed: _delete,
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: const Text('删除条目'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
