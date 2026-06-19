import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/settings/application/network_proxy_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/network_proxy_settings.dart';

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

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: '网络代理'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('代理设置'),
                const SizedBox(height: 16),
                _SwitchRow(
                  title: '启用网络代理',
                  description: '开启后，模型请求、自动获取模型和远程 MCP 连接将使用此代理',
                  value: settings.enabled,
                  onChanged: controller.setEnabled,
                ),
                const SizedBox(height: 16),
                _ProxyTypeField(
                  value: settings.type,
                  onChanged: controller.setType,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '服务器地址',
                  hint: '127.0.0.1',
                  controller: _hostController,
                  onChanged: controller.setHost,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '端口',
                  hint: '8080',
                  controller: _portController,
                  onChanged: controller.setPort,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '用户名',
                  hint: '可选',
                  controller: _usernameController,
                  onChanged: controller.setUsername,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '密码',
                  hint: '可选',
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: controller.setPassword,
                ),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '绕过规则',
                  hint: kDefaultNetworkProxyBypassRules,
                  helper: '用逗号、分号或空格分隔；支持 *、*.example.com 和 IPv4 CIDR',
                  controller: _bypassController,
                  maxLines: 3,
                  onChanged: controller.setBypassRules,
                ),
                const SizedBox(height: 8),
                const _Note(
                  text: '模型服务商自己的代理设置尚未接入时，全局代理作为默认网络出口；本地地址和内网地址会按绕过规则直连。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('连接测试'),
                const SizedBox(height: 16),
                ModelFormField(
                  label: '测试地址',
                  hint: 'https://www.google.com',
                  controller: _testUrlController,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ModelTonalButton(
                    label: _testing ? '测试中...' : '测试连接',
                    icon: LucideIcons.testTube2,
                    onPressed: _testing ? null : () => _testProxy(settings),
                  ),
                ),
                if (_testSucceeded != null) ...[
                  const SizedBox(height: 12),
                  _TestResult(success: _testSucceeded!, message: _testError),
                ],
              ],
            ),
          ),
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
    });

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (_) => true,
      ),
    );
    configureDioProxy(dio, config);
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
        _testError = error.toString();
      });
    } finally {
      dio.close(force: true);
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }
}

class _ProxyTypeField extends StatelessWidget {
  const _ProxyTypeField({required this.value, required this.onChanged});

  final NetworkProxyType value;
  final ValueChanged<NetworkProxyType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<NetworkProxyType>(
      initialValue: value,
      isExpanded: true,
      icon: Icon(
        LucideIcons.chevronDown,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      decoration: InputDecoration(
        labelText: '代理类型',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: const [
        DropdownMenuItem(value: NetworkProxyType.http, child: Text('HTTP')),
        DropdownMenuItem(value: NetworkProxyType.https, child: Text('HTTPS')),
        DropdownMenuItem(value: NetworkProxyType.socks5, child: Text('SOCKS5')),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TestResult extends StatelessWidget {
  const _TestResult({required this.success, this.message});

  final bool success;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success ? const Color(0xFF16A34A) : theme.colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            success ? '连接成功' : '连接失败：${message ?? '未知错误'}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
