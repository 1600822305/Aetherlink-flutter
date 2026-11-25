// 条目编辑页（全屏子页，零时长路由）：名称 / 内容 / 触发（关键词、正则、大小写、
// 扫描深度、常驻）/ 注入（位置、角色、深度、优先级）/ 计时器（sticky、cooldown、
// delay）。

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
  bool _saving = false;

  static TextEditingController _number(int value) =>
      TextEditingController(text: value.toString());

  @override
  void dispose() {
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

  Future<void> _save() async {
    if (_saving) return;
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

  List<Widget> _triggerSection() => [
    const WorldBookFormLabel('触发'),
    WorldBookSwitchRow(
      title: '常驻',
      subtitle: '始终注入，不检查关键词',
      value: _constantActive,
      onChanged: (v) => setState(() => _constantActive = v),
    ),
    if (!_constantActive) ...[
      WorldBookKeywordsField(
        keywords: _keywords,
        useRegex: _useRegex,
        onChanged: (v) => setState(() => _keywords = v),
      ),
      WorldBookSwitchRow(
        title: '正则表达式',
        subtitle: '把每个关键词当作正则匹配',
        value: _useRegex,
        onChanged: (v) => setState(() => _useRegex = v),
      ),
      WorldBookSwitchRow(
        title: '区分大小写',
        subtitle: '关闭时忽略大小写',
        value: _caseSensitive,
        onChanged: (v) => setState(() => _caseSensitive = v),
      ),
      WorldBookNumberField(
        controller: _scanDepth,
        label: '扫描深度',
        helper: '检查最近多少条消息（1–200）',
      ),
    ],
  ];

  List<Widget> _injectionSection() => [
    const WorldBookFormLabel('注入位置'),
    WorldBookPositionSelector(
      value: _position,
      onChanged: (v) => setState(() => _position = v),
    ),
    if (_position == WorldBookInjectionPosition.topOfChat ||
        _position == WorldBookInjectionPosition.bottomOfChat ||
        _position == WorldBookInjectionPosition.atDepth) ...[
      const WorldBookFormLabel('注入角色'),
      WorldBookRoleSelector(
        value: _role,
        onChanged: (v) => setState(() => _role = v),
      ),
    ],
    if (_position == WorldBookInjectionPosition.atDepth) ...[
      const SizedBox(height: 8),
      WorldBookNumberField(
        controller: _injectDepth,
        label: '注入深度',
        helper: '0 = 最后一条消息之后，1 = 最后一条之前（0–200）',
      ),
    ],
    const SizedBox(height: 8),
    WorldBookNumberField(
      controller: _priority,
      label: '优先级',
      helper: '数值越大越靠前注入（可为负，SillyTavern 导入的条目为 -order）',
      allowNegative: true,
    ),
  ];

  List<Widget> _timerSection() => [
    const WorldBookFormLabel('计时器'),
    WorldBookNumberField(
      controller: _sticky,
      label: '持续（sticky）',
      helper: '触发后继续生效的消息数，0 关闭',
    ),
    const SizedBox(height: 8),
    WorldBookNumberField(
      controller: _cooldown,
      label: '冷却（cooldown）',
      helper: '持续结束后不能再次触发的消息数，0 关闭',
    ),
    const SizedBox(height: 8),
    WorldBookNumberField(
      controller: _delay,
      label: '延迟（delay）',
      helper: '对话至少有多少条消息后才可触发，0 关闭',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildWorldBookAppBar(
        context,
        title: widget.entry == null ? '新建条目' : '编辑条目',
        onBack: () => Navigator.of(context).pop(),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.check, size: 22),
            color: Theme.of(context).colorScheme.primary,
            tooltip: '保存',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '条目名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '设定内容',
              alignLabelWithHint: true,
            ),
          ),
          ..._triggerSection(),
          ..._injectionSection(),
          ..._timerSection(),
        ],
      ),
    );
  }
}
