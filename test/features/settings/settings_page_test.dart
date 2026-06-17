import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/about_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_catalog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_item.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  // The hub is a long scrolling list; give the test a tall surface so every
  // row is laid out (a `ListView` only builds visible children otherwise).
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHub(WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(defaultThemeSpec),
          home: const SettingsPage(),
        ),
      ),
    );
  }

  testWidgets('renders the 设置 title and all six group titles in order', (
    tester,
  ) async {
    await pumpHub(tester);

    expect(find.text('设置'), findsOneWidget);
    for (final title in const [
      '基本设置',
      '模型服务',
      '提示词与工具',
      '快捷方式',
      '数据与知识',
      '系统',
    ]) {
      expect(find.text(title), findsOneWidget, reason: 'missing group $title');
    }
  });

  testWidgets('renders every catalog row with its title and a lucide icon', (
    tester,
  ) async {
    await pumpHub(tester);

    final allItems = kSettingsGroups.expand((g) => g.items).toList();
    // 2 + 5 + 4 + 1 + 6 + 3 = 21 rows.
    expect(allItems, hasLength(21));
    expect(find.byType(SettingItem), findsNWidgets(21));

    // A few representative titles and their lucide icons render (the icons are
    // lucide originals, not Icons.* approximations — ADR-0009).
    expect(find.text('外观'), findsOneWidget);
    expect(find.byIcon(LucideIcons.palette), findsOneWidget);
    expect(find.text('网络搜索'), findsOneWidget);
    expect(find.byIcon(LucideIcons.globe), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);

    // Every row shows the trailing chevron.
    expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(21));
  });

  testWidgets('only the wired rows (外观, 关于我们, 配置模型) are enabled; the rest are '
      'disabled placeholders', (tester) async {
    await pumpHub(tester);

    final rows = tester
        .widgetList<SettingItem>(find.byType(SettingItem))
        .toList();
    final enabled = rows.where((r) => r.enabled).toList();

    const wiredTitles = {'外观', '关于我们', '配置模型'};
    expect(enabled.map((r) => r.title).toSet(), wiredTitles);
    for (final row in enabled) {
      expect(row.onTap, isNotNull, reason: '${row.title} should be tappable');
    }

    for (final row in rows.where((r) => !wiredTitles.contains(r.title))) {
      expect(row.enabled, isFalse, reason: '${row.title} should be disabled');
      expect(row.onTap, isNull, reason: '${row.title} should not be tappable');
    }
  });

  testWidgets('compact/detailed toggle hides and shows descriptions', (
    tester,
  ) async {
    await pumpHub(tester);

    // Precondition: detailed mode (default) shows descriptions.
    expect(find.text('主题、字体大小和语言设置'), findsOneWidget);
    expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
    expect(find.byIcon(LucideIcons.list), findsNothing);

    // Switch to compact: descriptions disappear, toggle icon flips.
    await tester.tap(find.byIcon(LucideIcons.layoutGrid));
    await tester.pumpAndSettle();

    expect(find.text('主题、字体大小和语言设置'), findsNothing);
    expect(find.text('外观'), findsOneWidget); // titles stay
    expect(find.byIcon(LucideIcons.list), findsOneWidget);

    // Switch back to detailed: descriptions return.
    await tester.tap(find.byIcon(LucideIcons.list));
    await tester.pumpAndSettle();
    expect(find.text('主题、字体大小和语言设置'), findsOneWidget);
  });

  testWidgets('tapping 关于我们 navigates to the existing About page', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        currentTopicProvider.overrideWith((ref) => null),
        chatMessagesProvider.overrideWith((ref) => const <Message>[]),
      ],
    );
    addTearDown(container.dispose);
    final router = AppRouter.create();
    addTearDown(router.dispose);
    useTallSurface(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(defaultThemeSpec),
          routerConfig: router,
        ),
      ),
    );

    router.go(AppRouter.settingsPath);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('关于我们'), findsOneWidget);

    await tester.tap(find.text('关于我们'));
    await tester.pumpAndSettle();

    // The hub really navigates: the existing About page is now on screen.
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.text('AetherLink'), findsOneWidget);
  });
}
