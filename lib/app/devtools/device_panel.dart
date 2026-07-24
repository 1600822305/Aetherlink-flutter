import 'dart:io';

import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Page-level copy snapshot (devtools-design §5.5 "一键全量导出"): kept at library
/// scope so [DevicePanel.exportAsText] (which has no context) can return the text
/// the live view last assembled.
String _lastDeviceExport = '';

/// The Device & Env [DevToolsPanel]: device model / OS, screen & display, runtime
/// (build mode, locale, CPUs) and process memory, with a one-tap full export
/// (devtools-design §5.5). A bridge panel in `app/` so the dependency-free
/// `aetherlink_devtools` package needn't depend on device_info_plus.
class DevicePanel extends DevToolsPanel {
  const DevicePanel();

  @override
  String get title => '设备';

  @override
  IconData get icon => Icons.phone_iphone;

  @override
  Widget build(BuildContext context) => const _DeviceView();

  @override
  String exportAsText() => _lastDeviceExport;
}

class _DeviceView extends StatefulWidget {
  const _DeviceView();

  @override
  State<_DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<_DeviceView> {
  late final Future<Map<String, dynamic>> _deviceInfo = DeviceInfoPlugin()
      .deviceInfo
      .then((i) => i.data);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _deviceInfo,
      builder: (context, snap) {
        final sections = <_Section>[
          _Section('运行时', _runtime()),
          _Section('屏幕 / 显示', _display(context)),
          _Section('内存', _memory()),
          _Section(
            '设备',
            snap.connectionState != ConnectionState.done
                ? [const MapEntry('加载中…', '')]
                : (snap.hasError
                      ? [MapEntry('错误', '${snap.error}')]
                      : _flatten(snap.data ?? const {})),
          ),
        ];
        _lastDeviceExport = _exportText(sections);

        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
          children: [
            for (final s in sections) _SectionCard(section: s),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _copyAll(context),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('复制全部'),
            ),
          ],
        );
      },
    );
  }

  List<MapEntry<String, String>> _runtime() {
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';
    return [
      MapEntry('构建模式', mode),
      MapEntry(
        '操作系统',
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      ),
      MapEntry('Locale', Platform.localeName),
      MapEntry('CPU 核数', '${Platform.numberOfProcessors}'),
      MapEntry('Dart', Platform.version.split(' ').first),
    ];
  }

  List<MapEntry<String, String>> _display(BuildContext context) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final dpr = mq.devicePixelRatio;
    final size = mq.size;
    final phys = view.physicalSize;
    double refresh = 0;
    try {
      refresh = view.display.refreshRate;
    } catch (_) {}
    return [
      MapEntry(
        '逻辑分辨率',
        '${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)}',
      ),
      MapEntry(
        '物理分辨率',
        '${phys.width.toStringAsFixed(0)} × ${phys.height.toStringAsFixed(0)}',
      ),
      MapEntry('像素密度', '${dpr.toStringAsFixed(2)}x'),
      if (refresh > 0) MapEntry('刷新率', '${refresh.toStringAsFixed(0)} Hz'),
      MapEntry('文字缩放', mq.textScaler.scale(1).toStringAsFixed(2)),
      MapEntry(
        '亮度',
        mq.platformBrightness == Brightness.dark ? 'dark' : 'light',
      ),
      MapEntry(
        '安全区(上/下)',
        '${mq.padding.top.toStringAsFixed(0)} / ${mq.padding.bottom.toStringAsFixed(0)}',
      ),
    ];
  }

  List<MapEntry<String, String>> _memory() {
    String mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(0)} MB';
    final out = <MapEntry<String, String>>[];
    try {
      out.add(MapEntry('当前 RSS', mb(ProcessInfo.currentRss)));
      out.add(MapEntry('峰值 RSS', mb(ProcessInfo.maxRss)));
    } catch (_) {
      out.add(const MapEntry('RSS', '不可用'));
    }
    return out;
  }

  List<MapEntry<String, String>> _flatten(Map<String, dynamic> data) {
    final out = <MapEntry<String, String>>[];
    final keys = data.keys.toList()..sort();
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      if (v is Map || v is List) {
        out.add(MapEntry(k, v.toString()));
      } else {
        out.add(MapEntry(k, '$v'));
      }
    }
    return out;
  }

  String _exportText(List<_Section> sections) {
    final b = StringBuffer('=== 设备 / 环境 ===');
    for (final s in sections) {
      b.writeln();
      b.writeln('# ${s.title}');
      for (final e in s.rows) {
        b.writeln('${e.key}: ${e.value}');
      }
    }
    return b.toString();
  }

  Future<void> _copyAll(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _lastDeviceExport));
    if (context.mounted) {
      AppToast.success(context, '已复制设备信息');
    }
  }
}

class _Section {
  _Section(this.title, this.rows);

  final String title;
  final List<MapEntry<String, String>> rows;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final e in section.rows) _row(context, e.key, e.value),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
