import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/welcome/domain/welcome_content.dart';

part 'welcome_controller.g.dart';

/// Supplies the welcome page with its display text from the application layer
/// (the page stays a pure view — no business logic, see PROJECT_STRUCTURE).
///
/// Strings are static for M4.1, lifted verbatim from the original `welcome.*`
/// i18n namespace. A real i18n system is a separate later effort and is
/// intentionally not built here; when it lands only this provider changes, not
/// the view.
@riverpod
WelcomeContent welcomeContent(Ref ref) => const WelcomeContent(
  title: 'AetherLink',
  subtitle: '开始您的 AI 对话之旅',
  startButtonLabel: '开始使用',
);
