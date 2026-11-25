import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/settings/application/network_proxy_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/network_proxy_settings.dart';

/// 网络代理设置页 —— iOS 风格分组列表（V1）。
class NetworkProxySettingsPage extends ConsumerStatefulWidget {
  const NetworkProxySettingsPage({super.key});

  @override
  ConsumerState<NetworkProxySettingsPage> createState() =>
      _NetworkProxySettingsPageState();
}

class _NetworkProxySettingsPageState
    extends ConsumerState<NetworkProxySettingsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _bypassController;
  late final TextEditingController _testUrlController;

  bool _testing = false;
  bool? _testSucceeded;
  String? _testError;
  String? _testDetail;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(networkProxyControllerProvider);
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(text: settings.port);
    _usernameController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
    _bypassController = TextEditingController(text: settings.bypassRules);
    _testUrlController = TextEditingController(text: 'https://www.google.com');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _bypassController.dispose();
    _testUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(networkProxyControllerProvider);
    final controller = ref.read(networkProxyControllerProvider.notifier);

    _syncController(_hostController, settings.host);
    _syncController(_portController, settings.port);
    _syncController(_usernameController, settings.username);
    _syncController(_passwordController, settings.password);
    _syncController(_bypassController, settings.bypassRules);

    final enabled = settings.enabled;

    return Scaffold(
      backgroundColor: _GroupedColors.background(context),
      appBar: const ModelSettingsAppBar(title: '网络代理'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Group(
            children: [
              _Row(
                label: '启用网络代理',
                labelWidth: null,
                trailing: CustomSwitch(
                  value: enabled,
                  onChanged: controller.setEnabled,
                ),
              ),
            ],
          ),
          const _Footer('开启后，模型请求、获取模型和远程 MCP 将走此代理'),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header('服务器'),
                  _Group(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: _Segmented<NetworkProxyType>(
                          value: settings.type,
                          options: const [
                            (NetworkProxyType.http, 'HTTP'),
                            (NetworkProxyType.https, 'HTTPS'),
                            (NetworkProxyType.socks5, 'SOCKS5'),
                          ],
                          onChanged: controller.setType,
                        ),
                      ),
                      _InputRow(
                        label: '地址',
                        hint: '127.0.0.1',
                        controller: _hostController,
                        keyboardType: TextInputType.url,
                        onChanged: controller.setHost,
                      ),
                      _InputRow(
                        label: '端口',
                        hint: '8080',
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        onChanged: controller.setPort,
                      ),
                    ],
                  ),
                  const _Header('认证（可选）'),
                  _Group(
                    children: [
                      _InputRow(
                        label: '用户名',
                        hint: '未设置',
                        controller: _usernameController,
                        onChanged: controller.setUsername,
                      ),
                      _InputRow(
                        label: '密码',
                        hint: '未设置',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: controller.setPassword,
                        suffix: GestureDetector(
                          onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              _obscurePassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                              color: _GroupedColors.secondary(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const _Header('绕过规则'),
                  _Group(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: TextField(
                          controller: _bypassController,
                          onChanged: controller.setBypassRules,
                          minLines: 2,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontFamily: 'monospace',
                            color: _GroupedColors.value(context),
                          ),
                          decoration: _bareDecoration(
                            context,
                            kDefaultNetworkProxyBypassRules,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const _Footer(
                    '用逗号、分号或空格分隔，支持 *、*.example.com 和 CIDR。'
                    '匹配的地址将直连，不走代理。',
                  ),
                ],
              ),
            ),
          ),
          const _Header('连接测试'),
          _Group(
            children: [
              _InputRow(
                label: '地址',
                hint: 'https://www.google.com',
                controller: _testUrlController,
                keyboardType: TextInputType.url,
              ),
              _ActionRow(
                label: _testing ? '测试中…' : '测试连接',
                loading: _testing,
                onTap: _testing ? null : () => _testProxy(settings),
              ),
            ],
          ),
          if (_testSucceeded != null)
            _TestResult(success: _testSucceeded!, message: _testError, detail: _testDetail),
        ],
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    final selection = controller.selection;
    controller.text = value;
    if (selection.isValid && selection.baseOffset <= value.length) {
      controller.selection = selection;
    }
  }

  Future<void> _testProxy(NetworkProxySettings settings) async {
    final url = _testUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testSucceeded = false;
        _testError = '请输入测试地址';
      });
      return;
    }

    final config = settings.copyWith(enabled: true).toConfig();
    if (config == null) {
      setState(() {
        _testSucceeded = false;
        _testError = '请填写有效的服务器地址和端口';
      });
      return;
    }

    setState(() {
      _testing = true;
      _testSucceeded = null;
      _testError = null;
      _testDetail = null;
    });

    final dio = buildAppDio(
      proxy: config,
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (_) => true,
      ),
    );
    try {
      final response = await dio.get<dynamic>(url);
      if (!mounted) return;
      final status = response.statusCode ?? 0;
      setState(() {
        _testSucceeded = status >= 200 && status < 400;
        _testError = _testSucceeded == true ? null : 'HTTP $status';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _testError = _friendlyError(error);
        _testDetail = error.toString();
      });
    } finally {
      dio.close(force: true);
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 分组列表基础组件
// ---------------------------------------------------------------------------

abstract final class _GroupedColors {
  // 全部取自项目主题 token，与其它设置页保持一致，不写死颜色。
  static ColorScheme _cs(BuildContext c) => Theme.of(c).colorScheme;

  static Color background(BuildContext c) =>
      Theme.of(c).scaffoldBackgroundColor;

  static Color group(BuildContext c) => _cs(c).surface;

  static Color border(BuildContext c) => Theme.of(c).dividerColor;

  static Color divider(BuildContext c) => Theme.of(c).dividerColor;

  static Color secondary(BuildContext c) => _cs(c).onSurfaceVariant;

  static Color value(BuildContext c) => _cs(c).onSurface;

  static Color segmentTrack(BuildContext c) =>
      _cs(c).onSurface.withValues(alpha: 0.06);

  static Color segmentThumb(BuildContext c) => _cs(c).surface;
}

InputDecoration _bareDecoration(BuildContext context, String hint) {
  return InputDecoration(
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    contentPadding: EdgeInsets.zero,
    hintText: hint,
    hintStyle: TextStyle(
      color: _GroupedColors.secondary(context).withValues(alpha: 0.6),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          letterSpacing: 0.2,
          color: _GroupedColors.secondary(context),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: _GroupedColors.secondary(context),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = _GroupedColors.divider(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Divider(height: 0.5, thickness: 0.5, color: divider),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: _GroupedColors.group(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _GroupedColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.trailing,
    this.labelWidth = 72,
  });

  final String label;
  final Widget trailing;
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (labelWidth == null)
              Expanded(child: labelText)
            else
              SizedBox(width: labelWidth, child: labelText),
            if (labelWidth != null) const SizedBox(width: 8),
            if (labelWidth != null) Expanded(child: trailing) else trailing,
          ],
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      trailing: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                fontSize: 15,
                color: _GroupedColors.value(context),
              ),
              decoration: _bareDecoration(context, hint),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: onTap == null ? color.withValues(alpha: 0.5) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _GroupedColors.segmentTrack(context),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final (optionValue, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(optionValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: optionValue == value
                        ? _GroupedColors.segmentThumb(context)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: optionValue == value
                        ? const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface,
                      fontWeight: optionValue == value
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 把 Dio / Socket 异常翻译成简短的中文原因。
String _friendlyError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接代理超时，请检查地址、端口是否可达';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '已连上代理，但目标网站响应超时';
      case DioExceptionType.badCertificate:
        return '目标网站证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badResponse:
        return '服务器返回错误 HTTP ${error.response?.statusCode ?? ''}';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        break;
    }
    final inner = error.error;
    if (inner != null) return _friendlyError(inner);
  }
  final text = error.toString().toLowerCase();
  if (text.contains('auth') || text.contains('407') || text.contains('credential')) {
    return '代理认证失败，请检查用户名和密码';
  }
  if (text.contains('refused')) return '代理拒绝连接，请确认端口已开放';
  if (text.contains('unreachable') || text.contains('no route')) {
    return '网络不可达，无法连接到代理服务器';
  }
  if (text.contains('failed host lookup') || text.contains('nodename')) {
    return '无法解析地址，请检查服务器地址或测试地址';
  }
  if (text.contains('reset') || text.contains('closed') || text.contains('handshake')) {
    return '连接被中断，可能代理协议类型不匹配';
  }
  if (text.contains('timed out') || text.contains('timeout')) {
    return '连接超时，请检查代理是否可用';
  }
  return '未知错误';
}

class _TestResult extends StatefulWidget {
  const _TestResult({required this.success, this.message, this.detail});

  final bool success;
  final String? message;
  final String? detail;

  @override
  State<_TestResult> createState() => _TestResultState();
}

class _TestResultState extends State<_TestResult> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _TestResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.success
        ? const Color(0xFF16A34A)
        : theme.colorScheme.error;
    final hasDetail = !widget.success && (widget.detail?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasDetail ? () => setState(() => _expanded = !_expanded) : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    widget.success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
                    size: 14,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.success
                        ? '连接成功'
                        : '连接失败：${widget.message ?? '未知错误'}',
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: color),
                  ),
                ),
                if (hasDetail)
                  Text(
                    _expanded ? '收起' : '详情',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (hasDetail && _expanded) ...[
            const SizedBox(height: 6),
            SelectableText(
              widget.detail!,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
