import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_repository.dart';

part 'world_book_access.g.dart';

/// App-level composition seam for the 世界书 repository.
///
/// 与 `memory_access.dart` / `knowledge_access.dart` 同理：仓库实现需要单库
/// Drift 句柄，在组合根里装配，world_book 的 application 层只依赖 domain 接口。
/// P2 的发送管线注入（`collectWorldBookInjection`）也会落在本文件。
@Riverpod(keepAlive: true)
WorldBookRepository worldBookRepository(Ref ref) =>
    WorldBookRepositoryImpl(ref.watch(appDatabaseProvider).worldBookDao);
