import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/domain/about_info.dart';

part 'about_controller.g.dart';

// QQ group invite link (`QQ_GROUP_URL` in the original AboutPage.tsx).
const String _qqGroupUrl =
    'http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=V-b46WoBNLIM4oc34JMULwoyJ3hyrKac&authKey=q%2FSwCcxda4e55ygtwp3h9adQXhqBLZ9wJdvM0QxTjXQkbxAa2tHoraOGy2fiibyY&noverify=0&group_code=930126592';

/// Supplies the About page with its display state from the application layer
/// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
///
/// Values are ported verbatim from the original `AboutPage.tsx` /
/// `settings.about` zh-CN strings. The version comes from `package_info_plus`
/// at runtime, so pubspec.yaml's `version` is the single source of truth for
/// the About page, the Android versionName and the APK.
///
/// The "开发者工具" row points at the original's in-app `/devtools` page, which
/// does not exist in the Flutter app yet, so its [AboutLink.url] is `null` and
/// the row renders disabled (the settings hub's convention for unimplemented
/// destinations — no fake page).
@riverpod
Future<AboutInfo> aboutInfo(Ref ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AboutInfo(
    appName: 'AetherLink',
    description: '一个强大的AI助手应用，支持多种大语言模型，帮助您更高效地完成工作。',
    version: packageInfo.version,
    links: const <AboutLink>[
      AboutLink(
        kind: AboutLinkKind.github,
        title: 'GitHub',
        url: 'https://github.com/1600822305/CS-LLM-house',
      ),
      AboutLink(kind: AboutLinkKind.qqGroup, title: '官方群组', url: _qqGroupUrl),
      AboutLink(
        kind: AboutLinkKind.feedback,
        title: '反馈',
        url: 'https://github.com/1600822305/AetherLink/issues',
      ),
      AboutLink(kind: AboutLinkKind.devTools, title: '开发者工具'),
    ],
  );
}
