// Hook 全屏编辑页：按类型的表单 + 试跑 + 删除确认。
// 手动 hooks 全局生效（存储见 application/agent_manual_hooks.dart）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/hook_meta.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/hook_try_run_dialog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// 打开全屏编辑页；[index] 为空 = 新增，[template] 为模板预填。
void openHookEditPage(
  BuildContext context, {
  required AgentHookEvent event,
  int? index,
  AgentManualHook? template,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) =>
          HookEditPage(event: event, index: index, template: template),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// http header 行（值默认遮蔽，可切换明文）。
class _HeaderRow {
  _HeaderRow(String key, String value)
    : keyCtrl = TextEditingController(text: key),
      valueCtrl = TextEditingController(text: value);

  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  bool obscure = true;

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class HookEditPage extends ConsumerStatefulWidget {
  const HookEditPage({
    super.key,
    required this.event,
    this.index,
    this.template,
  });

  final AgentHookEvent event;
  final int? index;
  final AgentManualHook? template;

  @override
  ConsumerState<HookEditPage> createState() => _HookEditPageState();
}

class _HookEditPageState extends ConsumerState<HookEditPage> {
  AgentManualHook? get _existing => widget.index == null
      ? null
      : ref.read(agentManualHooksProvider)[widget.index!];

  late final AgentManualHook? _initial = widget.index != null
      ? _existing
      : widget.template;

  late AgentHookType _type = _initial?.hook.type ?? AgentHookType.command;
  late final TextEditingController _name = TextEditingController(
    text: _initial?.name ?? '',
  );
  // 三种类型各自的载体输入，切换类型不丢已输入内容。
  late final TextEditingController _command = TextEditingController(
    text: _initial?.hook.command ?? '',
  );
  late final TextEditingController _prompt = TextEditingController(
    text: _initial?.hook.prompt ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: _initial?.hook.url ?? '',
  );
  late final TextEditingController _matcher = TextEditingController(
    text: _initial?.hook.matcher ?? '*',
  );
  late final TextEditingController _pattern = TextEditingController(
    text: _initial?.hook.pattern ?? '*',
  );
  late final TextEditingController _timeout = TextEditingController(
    text: '${_initial?.hook.timeoutSeconds ?? kAgentHookDefaultTimeoutSeconds}',
  );
  late final TextEditingController _model = TextEditingController(
    text: _initial?.hook.model ?? '',
  );
  late final TextEditingController _statusMessage = TextEditingController(
    text: _initial?.hook.statusMessage ?? '',
  );
  late bool _once = _initial?.hook.once ?? false;
  late bool _asyncRewake = _initial?.hook.asyncRewake ?? false;
  late final List<_HeaderRow> _headers = [
    for (final e in (_initial?.hook.headers ?? const {}).entries)
      _HeaderRow(e.key, e.value),
  ];
  String? _error;
  bool _tryRunning = false;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _prompt.dispose();
    _url.dispose();
    _matcher.dispose();
    _pattern.dispose();
    _timeout.dispose();
    _model.dispose();
    _statusMessage.dispose();
    for (final row in _headers) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _toolEvent =>
      widget.event == AgentHookEvent.preToolUse ||
      widget.event == AgentHookEvent.postToolUse ||
      widget.event == AgentHookEvent.postToolUseFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = hookEventMetaOf(widget.event);
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(
          widget.index == null ? '新增 ${meta.title}' : '编辑 ${meta.title}',
        ),
        actions: [
          TextButton(onPressed: _submit, child: const Text('保存')),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            meta.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AgentHookType>(
            segments: [
              for (final type in AgentHookType.values)
                ButtonSegment(
                  value: type,
                  icon: Icon(hookTypeMetaOf(type).icon, size: 14),
                  label: Text(hookTypeMetaOf(type).label),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称（可选）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          ..._payloadFields(theme),
          if (_toolEvent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _matcher,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '匹配工具（* 全部）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final suggestion in kHookMatcherSuggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _matcher.text = suggestion),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pattern,
              decoration: InputDecoration(
                labelText: '匹配 pattern（* 全部）',
                helperText: _patternHelper(),
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _timeout,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '超时（秒）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_type == AgentHookType.prompt ||
              _type == AgentHookType.agent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: '裁决模型 id（可选，缺省用当前默认模型）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _statusMessage,
            decoration: const InputDecoration(
              labelText: '运行中文案（可选，显示在任务时间线）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          ListTile(
            onTap: () => setState(() => _once = !_once),
            trailing: CustomSwitch(
              value: _once,
              onChanged: (v) => setState(() => _once = v),
            ),
            title: const Text('只触发一次（once）'),
            subtitle: const Text('本次任务内命中一次后不再触发'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (_type == AgentHookType.command)
            ListTile(
              onTap: () => setState(() => _asyncRewake = !_asyncRewake),
              trailing: CustomSwitch(
                value: _asyncRewake,
                onChanged: (v) => setState(() => _asyncRewake = v),
              ),
              title: const Text('后台运行并叫醒（asyncRewake）'),
              subtitle: const Text('不阻塞主链；后台跑完若阻断（退出码 2）把反馈注入任务叫醒模型'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _tryRunning ? null : _tryRun,
            icon: _tryRunning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.play, size: 14),
            label: Text(_tryRunning ? '试跑中…' : '试跑（用示例上下文执行一次）'),
          ),
          if (widget.index != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _confirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('删除此 hook'),
            ),
          ],
        ],
      ),
    );
  }

  /// pattern 的语义随 matcher 变化：终端工具匹配子命令，其余匹配文件路径。
  String _patternHelper() {
    final matcher = _matcher.text.trim();
    if (matcher.startsWith('terminal')) {
      return '终端工具：匹配子命令，如 git push * / rm *';
    }
    if (matcher == '*' || matcher.isEmpty) {
      return '终端工具匹配子命令（git push *）；文件工具匹配路径 glob（lib/**）';
    }
    return '文件类工具：匹配文件路径 glob，如 lib/** / *.dart';
  }

  /// 按类型的载体输入区：命令 / 提示词 / URL+headers。
  List<Widget> _payloadFields(ThemeData theme) => switch (_type) {
    AgentHookType.command => [
      TextField(
        controller: _command,
        maxLines: 4,
        minLines: 1,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          labelText: '命令（必填）',
          helperText:
              '跑在任务绑定工作区的终端里；stdin 喷入 hook 输入 JSON，'
              '退出码 2 阻断，stdout 可输出 decision JSON',
          helperMaxLines: 3,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ],
    AgentHookType.prompt => [
      TextField(
        controller: _prompt,
        maxLines: 10,
        minLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: '提示词（必填）',
          helperText:
              '用当前默认模型做一次裁决；\$ARGUMENTS 替换为 hook 输入 '
              'JSON（缺省追加到末尾），模型回 {"ok":false,"reason":"..."} 即阻断',
          helperMaxLines: 3,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ],
    AgentHookType.agent => [
      TextField(
        controller: _prompt,
        maxLines: 10,
        minLines: 4,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          labelText: '校验提示词（必填）',
          helperText:
              '多轮带工具（工作区终端）的小智能体校验；'
              '\$ARGUMENTS 替换为 hook 输入 JSON，智能体通过 '
              'submit_result 交回 {"ok":false,"reason":"..."} 即阻断',
          helperMaxLines: 3,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ],
    AgentHookType.http => [
      TextField(
        controller: _url,
        keyboardType: TextInputType.url,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          labelText: 'URL（必填，http/https）',
          helperText: 'POST hook 输入 JSON；响应体按 decision JSON 协议解析',
          helperMaxLines: 2,
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              '自定义 headers（可选）',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _headers.add(_HeaderRow('', ''))),
            icon: const Icon(LucideIcons.plus, size: 14),
            label: const Text('添加'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
      for (var i = 0; i < _headers.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _headers[i].keyCtrl,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Header',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _headers[i].valueCtrl,
                obscureText: _headers[i].obscure,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  labelText: '值',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _headers[i].obscure = !_headers[i].obscure,
                    ),
                    icon: Icon(
                      _headers[i].obscure
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: 14,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _headers.removeAt(i).dispose();
              }),
              icon: const Icon(LucideIcons.x, size: 16),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    ],
  };

  /// 表单校验；通过时返回构建好的 hook，否则设置 [_error] 并返回 null。
  AgentManualHook? _validate() {
    final payload = switch (_type) {
      AgentHookType.command => _command.text.trim(),
      AgentHookType.prompt || AgentHookType.agent => _prompt.text.trim(),
      AgentHookType.http => _url.text.trim(),
    };
    if (payload.isEmpty) {
      setState(
        () => _error = switch (_type) {
          AgentHookType.command => '命令不能为空',
          AgentHookType.prompt || AgentHookType.agent => '提示词不能为空',
          AgentHookType.http => 'URL 不能为空',
        },
      );
      return null;
    }
    if (_type == AgentHookType.http) {
      final uri = Uri.tryParse(payload);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        setState(() => _error = 'URL 必须是合法的 http/https 地址');
        return null;
      }
    }
    final timeoutText = _timeout.text.trim();
    final timeout = int.tryParse(timeoutText);
    if (timeoutText.isNotEmpty && (timeout == null || timeout <= 0)) {
      setState(() => _error = '超时必须是正整数（秒）');
      return null;
    }
    final headers = <String, String>{
      for (final row in _headers)
        if (row.keyCtrl.text.trim().isNotEmpty)
          row.keyCtrl.text.trim(): row.valueCtrl.text,
    };
    final name = _name.text.trim();
    final matcher = _matcher.text.trim();
    final pattern = _pattern.text.trim();
    setState(() => _error = null);
    return AgentManualHook(
      name: name.isEmpty ? payload : name,
      enabled: _existing?.enabled ?? true,
      hook: AgentHook(
        event: widget.event,
        type: _type,
        matcher: matcher.isEmpty ? '*' : matcher,
        pattern: pattern.isEmpty ? '*' : pattern,
        command: _type == AgentHookType.command ? payload : '',
        prompt: _type == AgentHookType.prompt || _type == AgentHookType.agent
            ? payload
            : '',
        url: _type == AgentHookType.http ? payload : '',
        headers: _type == AgentHookType.http ? headers : const {},
        timeoutSeconds: timeout != null && timeout > 0
            ? timeout
            : kAgentHookDefaultTimeoutSeconds,
        model: _type == AgentHookType.prompt || _type == AgentHookType.agent
            ? _model.text.trim()
            : '',
        statusMessage: _statusMessage.text.trim(),
        once: _once,
        asyncRewake: _type == AgentHookType.command ? _asyncRewake : false,
      ),
    );
  }

  void _submit() {
    final hook = _validate();
    if (hook == null) return;
    final notifier = ref.read(agentManualHooksProvider.notifier);
    if (widget.index == null) {
      notifier.add(hook);
    } else {
      notifier.updateAt(widget.index!, hook);
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除此 hook？'),
        content: Text('「${_existing?.name ?? ''}」删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(agentManualHooksProvider.notifier).removeAt(widget.index!);
    Navigator.of(context).pop();
  }

  /// 试跑：用当前表单值（未保存也可以）+ 示例上下文执行一次。
  /// command 型需要选一个工作区（跑在它的终端里）。
  Future<void> _tryRun() async {
    final manual = _validate();
    if (manual == null) return;
    String? workspaceId;
    if (_type == AgentHookType.command || _type == AgentHookType.agent) {
      final workspaces = ref.read(recentWorkspacesViewProvider);
      if (workspaces.isEmpty) {
        setState(() => _error = '试跑此类型 hook 需要先打开过一个工作区');
        return;
      }
      if (!mounted) return;
      workspaceId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('在哪个工作区试跑？'),
          children: [
            for (final ws in workspaces)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(ws.id),
                child: Text(ws.name),
              ),
          ],
        ),
      );
      if (workspaceId == null) return;
    }
    setState(() => _tryRunning = true);
    final stopwatch = Stopwatch()..start();
    final result = await ref.read(agentHookTryRunProvider)(
      manual.hook,
      workspaceId: workspaceId,
    );
    stopwatch.stop();
    if (!mounted) return;
    setState(() => _tryRunning = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          HookTryRunResultDialog(result: result, elapsed: stopwatch.elapsed),
    );
  }
}
