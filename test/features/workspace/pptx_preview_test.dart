// .pptx 工作区预览：文件名判定 + 真实 pptx 字节的逐页内容渲染 + 坏文件报错。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/pptx_preview.dart';
import 'package:aetherlink_pptx/aetherlink_pptx.dart';

/// 只喂固定字节的后端：预览组件只用 readFileBytes。
class _BytesBackend extends WorkspaceBackend {
  _BytesBackend(this.bytes);

  final List<int> bytes;

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
        canExec: false,
        canWatch: false,
        isRemote: false,
      );

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async => const [];

  @override
  Future<String> readFile(String path) async =>
      throw UnsupportedError('bytes only');

  @override
  Future<List<int>> readFileBytes(
    String path, {
    int offset = 0,
    int? length,
  }) async => bytes;
}

WorkspaceEntry _entry(String name, int size) => WorkspaceEntry(
      name: name,
      path: '/ws/$name',
      isDirectory: false,
      size: size,
      mtime: 0,
      isHidden: false,
    );

void main() {
  group('isPptxFileName', () {
    test('matches .pptx / .potx only', () {
      expect(isPptxFileName('演示.pptx'), isTrue);
      expect(isPptxFileName('A.PPTX'), isTrue);
      expect(isPptxFileName('模板.potx'), isTrue);
      expect(isPptxFileName('a.ppt'), isFalse);
      expect(isPptxFileName('a.pptx.bak'), isFalse);
      expect(isPptxFileName('pptx'), isFalse);
    });
  });

  group('PptxPreview', () {
    testWidgets('renders slide text and notes from real pptx bytes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final deck = DeckDocument.fromJson({
          'layout': '16x9',
          'title': '测试演示',
          'slides': [
            {
              'notes': '演讲提示',
              'elements': [
                {
                  'type': 'text',
                  'x': 1,
                  'y': 1,
                  'w': 11,
                  'h': 1.5,
                  'text': '预览标题',
                },
              ],
            },
          ],
        });
        final bytes = buildPptxBytes(deck);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PptxPreview(
                  entry: _entry('测试.pptx', bytes.length),
                  backend: _BytesBackend(bytes),
                ),
              ),
            ),
          ),
        );
        // FutureBuilder + compute 是真实异步，轮询直到解析完成。
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
          if (find.text('预览标题').evaluate().isNotEmpty) break;
        }
        expect(find.text('预览标题'), findsOneWidget);
        expect(find.text('第 1 页'), findsOneWidget);
        expect(find.textContaining('演讲提示'), findsOneWidget);
      });
    });

    testWidgets('shows a readable error for invalid bytes', (tester) async {
      await tester.runAsync(() async {
        final bytes = Uint8List.fromList(List.filled(64, 0x42));
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PptxPreview(
                  entry: _entry('坏文件.pptx', bytes.length),
                  backend: _BytesBackend(bytes),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
          if (find.text('无法解析该演示文稿').evaluate().isNotEmpty) break;
        }
        expect(find.text('无法解析该演示文稿'), findsOneWidget);
      });
    });
  });
}
