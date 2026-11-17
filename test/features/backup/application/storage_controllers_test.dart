import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/storage_access.dart';
import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_media_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media_repository.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_repository.dart';
import 'package:aetherlink_flutter/features/backup/domain/topic_storage_usage.dart';

class _StorageRepository implements StorageRepository {
  StorageReport report = StorageReport({});
  List<TopicStorageUsage> topics = const [];
  Future<StorageReport> Function()? onScan;
  Object? topicError;
  int scans = 0;
  int actions = 0;

  @override
  Future<StorageReport> scan() async {
    scans++;
    return onScan == null ? report : await onScan!();
  }

  @override
  Future<List<TopicStorageUsage>> topicUsage() async {
    if (topicError != null) throw topicError!;
    return topics;
  }

  @override
  Future<void> clean(StorageCleanup target) async { actions++; }

  @override
  Future<void> cleanItem(String id) async { actions++; }

  @override
  Future<void> vacuum() async { actions++; }
}

class _MediaRepository implements StorageMediaRepository {
  List<StorageMedia> items = const [];
  Future<List<StorageMedia>> Function()? onLoad;
  int loads = 0;
  int deletions = 0;

  @override
  Future<List<StorageMedia>> load() async {
    loads++;
    return onLoad == null ? items : await onLoad!();
  }

  @override
  Future<String> blockPayload(String id) async => '{}';

  @override
  Future<StorageMediaDeletion> deleteUnused(Set<String> ids) async {
    deletions++;
    return StorageMediaDeletion(deleted: ids.length, kept: 0);
  }
}

class _IdleBackup extends BackupController {
  @override
  BackupState build() => const BackupState();
}

void main() {
  late _StorageRepository storage;
  late _MediaRepository media;
  late ProviderContainer container;

  setUp(() {
    storage = _StorageRepository();
    media = _MediaRepository();
    container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(storage),
      storageMediaRepositoryProvider.overrideWithValue(media),
      backupControllerProvider.overrideWith(_IdleBackup.new),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  final item = StorageMedia(
    id: 'disk:file', name: 'file', source: '/file', mimeType: 'text/plain',
    bytes: 3, modifiedAt: DateTime(2026), filter: StorageMediaFilter.tools,
    isInUse: false,
  );

  test('cached report stays visible without loading during revalidation', () async {
    final controller = container.read(storageControllerProvider.notifier);
    expect(container.read(storageControllerProvider).isLoading, isTrue);
    await controller.refresh();
    final cached = container.read(storageControllerProvider).report;
    final gate = Completer<StorageReport>();
    storage.onScan = () => gate.future;
    final loading = <bool>[];
    container.listen(storageControllerProvider, (_, next) => loading.add(next.isLoading));
    final refresh = controller.refresh();
    await flush();
    expect(container.read(storageControllerProvider).report, same(cached));
    expect(container.read(storageControllerProvider).isLoading, isFalse);
    final updated = StorageReport({StorageCategory.chat: const StorageUsage(bytes: 10)});
    gate.complete(updated);
    await refresh;
    expect(container.read(storageControllerProvider).report, same(updated));
    expect(loading, everyElement(isFalse));
  });

  test('scan and topic failures retain the complete cached snapshot', () async {
    final controller = container.read(storageControllerProvider.notifier);
    storage.topics = const [TopicStorageUsage(id: 't', title: '话题', assistantName: '助手',
      bytes: 1, messageCount: 1, imageCount: 0, videoCount: 0)];
    await controller.refresh();
    final cached = container.read(storageControllerProvider);
    storage.onScan = () async => throw StateError('scan failed');
    await controller.refresh();
    expect(container.read(storageControllerProvider).report, same(cached.report));
    expect(container.read(storageControllerProvider).topics, same(cached.topics));
    expect(container.read(storageControllerProvider).error, contains('scan failed'));
    expect(container.read(storageControllerProvider).isLoading, isFalse);
    storage.onScan = null;
    storage.report = StorageReport({});
    storage.topicError = StateError('topics failed');
    await controller.refresh();
    expect(container.read(storageControllerProvider).report, same(cached.report));
    expect(container.read(storageControllerProvider).topics, same(cached.topics));
    storage.topicError = null;
    await controller.refresh();
    expect(container.read(storageControllerProvider).error, isNull);
  });

  test('cached media, including an empty list, never returns to loading', () async {
    final controller = container.read(storageMediaControllerProvider.notifier);
    await controller.refresh();
    expect(container.read(storageMediaControllerProvider).hasLoaded, isTrue);
    final gate = Completer<List<StorageMedia>>();
    media.onLoad = () => gate.future;
    final refresh = controller.refresh();
    await flush();
    expect(container.read(storageMediaControllerProvider).items, isEmpty);
    expect(container.read(storageMediaControllerProvider).isLoading, isFalse);
    gate.complete([item]);
    await refresh;
    expect(container.read(storageMediaControllerProvider).items, [item]);
  });

  test('failed media revalidation keeps old items and can recover', () async {
    media.items = [item];
    final controller = container.read(storageMediaControllerProvider.notifier);
    await controller.refresh();
    final cached = container.read(storageMediaControllerProvider).items;
    media.onLoad = () async => throw StateError('media failed');
    await controller.refresh();
    final state = container.read(storageMediaControllerProvider);
    expect(state.items, same(cached));
    expect(state.isLoading, isFalse);
    expect(state.hasLoaded, isTrue);
    expect(state.error, contains('media failed'));
    media.onLoad = null;
    await controller.refresh();
    expect(container.read(storageMediaControllerProvider).error, isNull);
  });

  test('both controllers share in-flight refresh futures', () async {
    final controller = container.read(storageControllerProvider.notifier);
    final mediaController = container.read(storageMediaControllerProvider.notifier);
    final reportGate = Completer<StorageReport>();
    final mediaGate = Completer<List<StorageMedia>>();
    storage.onScan = () => reportGate.future;
    media.onLoad = () => mediaGate.future;
    final first = controller.refresh();
    final mediaFirst = mediaController.refresh();
    expect(controller.refresh(), same(first));
    expect(mediaController.refresh(), same(mediaFirst));
    await flush();
    expect(storage.scans, 1);
    expect(media.loads, 1);
    reportGate.complete(storage.report);
    mediaGate.complete([]);
    await Future.wait([first, mediaFirst]);
  });

  test('both providers retain results after the last listener leaves', () async {
    final reportSubscription = container.listen(storageControllerProvider, (_, _) {});
    final mediaSubscription = container.listen(storageMediaControllerProvider, (_, _) {});
    await container.read(storageControllerProvider.notifier).refresh();
    await container.read(storageMediaControllerProvider.notifier).refresh();
    final report = container.read(storageControllerProvider).report;
    reportSubscription.close();
    mediaSubscription.close();
    await flush();
    expect(container.read(storageControllerProvider).report, same(report));
    expect(container.read(storageMediaControllerProvider).hasLoaded, isTrue);
    expect(storage.scans, 1);
    expect(media.loads, 1);
  });

  test('forced revalidation waits for the old flight then shares a fresh flight', () async {
    final controller = container.read(storageControllerProvider.notifier);
    final gate = Completer<StorageReport>();
    storage.onScan = () => gate.future;
    final first = controller.refresh();
    final forced = controller.refresh(force: true);
    final alsoForced = controller.refresh(force: true);
    await flush();
    expect(storage.scans, 1);
    storage.onScan = null;
    gate.complete(storage.report);
    await Future.wait([first, forced, alsoForced]);
    expect(storage.scans, 2);
  });

  test('maintenance waits for a running scan and forces both snapshots afterwards', () async {
    final controller = container.read(storageControllerProvider.notifier);
    await controller.refresh();
    await container.read(storageMediaControllerProvider.notifier).refresh();
    final gate = Completer<StorageReport>();
    storage.onScan = () => gate.future;
    final scanning = controller.refresh();
    await flush();
    final cleaning = controller.clean(StorageCleanup.cache);
    await flush();
    expect(storage.actions, 0);
    expect(container.read(storageControllerProvider).isBusy, isTrue);
    storage.onScan = null;
    gate.complete(storage.report);
    await Future.wait([scanning, cleaning]);
    expect(storage.actions, 1);
    expect(storage.scans, 3);
    expect(media.loads, 2);
    expect(container.read(storageControllerProvider).isBusy, isFalse);
  });

  test('first-load failures stay retryable without inventing a cached result', () async {
    storage.onScan = () async => throw StateError('scan failed');
    media.onLoad = () async => throw StateError('media failed');
    await container.read(storageControllerProvider.notifier).refresh();
    await container.read(storageMediaControllerProvider.notifier).refresh();
    expect(container.read(storageControllerProvider).report, isNull);
    expect(container.read(storageControllerProvider).isLoading, isFalse);
    expect(container.read(storageMediaControllerProvider).hasLoaded, isFalse);
    expect(container.read(storageMediaControllerProvider).isLoading, isFalse);
    storage.onScan = null;
    media.onLoad = null;
    await container.read(storageControllerProvider.notifier).refresh();
    await container.read(storageMediaControllerProvider.notifier).refresh();
    expect(container.read(storageControllerProvider).report, isNotNull);
    expect(container.read(storageMediaControllerProvider).hasLoaded, isTrue);
  });

  test('media deletion waits for a running load and refreshes both snapshots', () async {
    final controller = container.read(storageMediaControllerProvider.notifier);
    await controller.refresh();
    final gate = Completer<List<StorageMedia>>();
    media.onLoad = () => gate.future;
    final loading = controller.refresh();
    await flush();
    final deleting = controller.deleteUnused({'disk:file'});
    await flush();
    expect(media.deletions, 0);
    expect(container.read(storageMediaControllerProvider).isBusy, isTrue);
    media.onLoad = null;
    gate.complete([]);
    await loading;
    await deleting;
    expect(media.deletions, 1);
    expect(media.loads, 3);
    expect(storage.scans, 1);
    expect(container.read(storageMediaControllerProvider).isBusy, isFalse);
  });
}
