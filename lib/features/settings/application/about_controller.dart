import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/domain/about_info.dart';

part 'about_controller.g.dart';

/// Supplies the About page with its display state from the application layer
/// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
///
/// Values are static for M4.0 (ported from the original `AboutPage.tsx`). The
/// version can later be sourced from `package_info_plus` without touching the
/// view — only this provider changes.
@riverpod
AboutInfo aboutInfo(Ref ref) => const AboutInfo(
  appName: 'AetherLink',
  description: 'AI 对话助手',
  version: '0.6.5',
  links: <AboutLink>[
    AboutLink(
      label: 'GitHub',
      url: 'https://github.com/1600822305/CS-LLM-house',
    ),
    AboutLink(
      label: '反馈',
      url: 'https://github.com/1600822305/AetherLink/issues',
    ),
  ],
);
