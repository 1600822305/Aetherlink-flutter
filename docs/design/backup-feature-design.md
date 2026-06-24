# Aetherlink Flutter - 数据备份与恢复 设计文档

> **版本**: v1.0  
> **日期**: 2026-06-23  
> **状态**: 设计阶段  
> **范围**: 第一期（本地备份 + WebDAV + 恢复）

---

## 1. 背景与目标

### 1.1 背景

Aetherlink Flutter 版目前使用 Drift (SQLite) 作为持久化方案，存储对话、消息、助手、模型供应商、分组、设置等数据。当前没有任何备份/恢复机制，用户数据存在丢失风险：

- 卸载重装丢失所有数据
- 设备损坏无法恢复
- 版本升级 schema 变更时潜在的迁移失败
- 用户无法在多设备间同步数据

### 1.2 目标

1. **不丢数据** — 任何破坏性操作前自动备份
2. **跨版本兼容** — 新旧版本备份文件可互相恢复
3. **跨平台兼容** — Flutter 版与 Web 版备份格式互通
4. **安全可靠** — 原子操作、完整性校验、事务保护

### 1.3 参考实现

| 项目 | 语言/框架 | 参考重点 |
|------|-----------|---------|
| kelivo | Flutter | 整体架构、WebDAV/S3 实现、ZIP 打包策略、Isolate 异步 |
| rikkahub | Kotlin/Compose | WebDAV client 设计、恢复策略、错误处理 |
| AetherLink Web | TypeScript/React | 备份 JSON 格式定义、选择性备份、版本号管理 |

---

## 2. 数据模型

### 2.1 当前数据库结构

```
AppDatabase (Drift/SQLite, schemaVersion: 4)
├── TopicRows        → Topic JSON blob (对话/话题)
├── MessageRows      → Message JSON blob (消息, 按 topicId/assistantId 索引)
├── MessageBlockRows → MessageBlock JSON blob (消息块, 按 messageId 索引)
├── AssistantRows    → Assistant JSON blob (助手配置)
├── ProviderRows     → ModelProvider JSON blob (模型供应商, 含 sortOrder)
├── GroupRows        → Group JSON blob (分组, 含 orderIndex)
└── AppSettingRows   → key-value 字符串 (应用设置)
```

数据库文件路径: `getApplicationDocumentsDirectory()/aetherlink.sqlite`

### 2.2 备份文件结构

采用 **ZIP 压缩包**格式，内部为标准 JSON 文件：

```
aetherlink_backup_2026-06-23T15-30-00.zip
├── manifest.json          ← 元数据（版本、校验、统计）
├── topics.json            ← 对话列表
├── messages.json          ← 所有消息
├── message_blocks.json    ← 消息块
├── assistants.json        ← 助手配置
├── providers.json         ← 模型供应商（脱敏：API Key 可选加密）
├── groups.json            ← 分组
├── settings.json          ← 应用设置 (key-value)
└── files/                 ← 附件文件（头像等，第二期）
```

### 2.3 manifest.json 规格

```json
{
  "version": 1,
  "appVersion": "1.0.0",
  "platform": "flutter",
  "schemaVersion": 4,
  "createdAt": "2026-06-23T15:30:00.000Z",
  "deviceInfo": "Xiaomi 14 Pro / Android 15",
  "checksum": "sha256:abcdef1234567890...",
  "stats": {
    "topics": 42,
    "messages": 1280,
    "messageBlocks": 3500,
    "assistants": 5,
    "providers": 3,
    "groups": 2,
    "settings": 15
  },
  "options": {
    "includeMessages": true,
    "includeProviders": true,
    "includeSettings": true,
    "encryptApiKeys": false
  }
}
```

字段说明：
- `version`: manifest 格式版本（用于 manifest 自身的向前兼容）
- `schemaVersion`: 对应 AppDatabase.schemaVersion，标记数据结构版本
- `checksum`: 除 manifest.json 外所有文件的内容拼接后 SHA-256
- `stats`: 各表记录数量，恢复前展示给用户确认

---

## 3. 版本兼容性策略

### 3.1 场景矩阵

| 场景 | 方向 | 处理策略 |
|------|------|---------|
| Flutter v1 备份 → Flutter v2 恢复 | 低→高 | **向前兼容**: 缺失字段自动填充默认值 |
| Flutter v2 备份 → Flutter v1 恢复 | 高→低 | **向后宽容**: 未知字段 JSON 解析时忽略 |
| Web 备份 → Flutter 恢复 | 跨平台 | **格式适配**: 识别 Web JSON 结构并转换 |
| Flutter 备份 → Web 恢复 | 跨平台 | **兼容导出**: 提供"导出 Web 格式"选项 |
| 恢复中途崩溃 | 异常 | **事务保护**: 原子操作，失败回滚 |

### 3.2 向前兼容实现（低版本备份 → 高版本 app）

```dart
/// 恢复时检查 schemaVersion，对低版本数据应用补丁
Topic _migrateTopic(Map<String, dynamic> json, int sourceSchema) {
  // schema v5 新增 "pinned" 字段
  if (sourceSchema < 5) {
    json.putIfAbsent('pinned', () => false);
  }
  return Topic.fromJson(json);
}
```

- 每次 schema 升级同步维护一个 `_migrateTopic` / `_migrateMessage` 等函数
- 采用**累积式迁移**（不需要逐版本跳转，直接从任意旧版本到当前版本）

### 3.3 向后宽容实现（高版本备份 → 低版本 app）

```dart
/// JSON 反序列化统一使用宽松模式
@JsonSerializable(
  createFactory: true,
  disallowUnrecognizedKeys: false,  // ← 忽略未知字段
)
class Topic { ... }
```

- Drift JSON 列存储的是完整 JSON blob，**额外字段不会被删除**
- 低版本 app 读取时只取自己认识的字段，其余原样保留在 blob 中
- 这意味着数据经过低版本 app "过手"后，高版本字段仍在（不会被 trim 掉）

### 3.4 跨平台兼容（Web ↔ Flutter）

**Web 版备份格式**（单个 JSON 文件）：
```json
{
  "version": 5,
  "topics": [...],
  "assistants": [...],
  "settings": { "key": "value", ... },
  "modelConfig": { ... },
  "localStorage": { ... }
}
```

**适配策略**：
1. 导入时检测文件格式：
   - `.zip` → Flutter 原生格式
   - `.json` → 尝试解析为 Web 格式
2. Web 格式适配器将 Web JSON 结构映射到 Flutter 数据模型
3. 导出时提供选项："Flutter 格式 (ZIP)" 或 "Web 兼容格式 (JSON)"

---

## 4. 核心流程

### 4.1 本地备份流程

```
用户点击"备份" / 系统自动触发
        │
        ▼
┌─────────────────────┐
│ 1. 事务读取全部数据  │  ← Drift snapshot isolation
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 2. 序列化为 JSON    │  ← 主线程
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 3. 计算 checksum    │  ← SHA-256
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 4. 生成 manifest    │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 5. ZIP 打包         │  ← Isolate (不阻塞 UI)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 6. 保存/分享/上传   │
└─────────────────────┘
```

### 4.2 本地恢复流程

```
用户选择备份文件
        │
        ▼
┌────────────────────────────┐
│ 1. 解压 ZIP                │  ← Isolate
└─────────┬──────────────────┘
          │
          ▼
┌────────────────────────────┐
│ 2. 读取 manifest.json      │
│    - 校验 checksum          │
│    - 检查 schemaVersion     │
│    - 提取 stats 展示给用户  │
└─────────┬──────────────────┘
          │
          ▼
┌────────────────────────────┐
│ 3. 用户确认                │  ← 展示数据摘要 + 选择恢复模式
│    - 覆盖模式 / 合并模式   │
└─────────┬──────────────────┘
          │
          ▼
┌────────────────────────────────────────┐
│ 4. 【安全网】自动备份当前数据          │  ← 恢复前先保存一份
└─────────┬──────────────────────────────┘
          │
          ▼
┌────────────────────────────┐
│ 5. 在事务内恢复数据        │
│    - 覆盖: 清空表 → 写入   │
│    - 合并: 按 ID 去重合并  │
│    - 版本迁移补丁          │
└─────────┬──────────────────┘
          │
          ▼
┌────────────────────────────┐
│ 6. 提交事务                │  ← 失败则回滚，原数据不变
└─────────┬──────────────────┘
          │
          ▼
┌────────────────────────────┐
│ 7. 通知 UI 刷新            │
└────────────────────────────┘
```

### 4.3 WebDAV 备份流程

```
用户配置 WebDAV 服务器
        │
        ▼
┌──────────────────────────┐
│ 1. 测试连接 (PROPFIND)   │
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 2. 确保备份目录存在       │  ← MKCOL
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 3. prepareBackupFile()   │  ← 同本地备份 1-5 步
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 4. 流式上传 (PUT)        │  ← 不将整个文件载入内存
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 5. 清理临时文件          │
└──────────────────────────┘
```

### 4.4 WebDAV 恢复流程

```
用户点击"从 WebDAV 恢复"
        │
        ▼
┌──────────────────────────┐
│ 1. PROPFIND 列出备份文件  │
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 2. 展示文件列表           │  ← 按时间倒序，显示大小/日期
│    用户选择一个备份        │
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 3. 流式下载 (GET)        │
└─────────┬────────────────┘
          │
          ▼
┌──────────────────────────┐
│ 4. 同本地恢复流程 2-7     │
└──────────────────────────┘
```

---

## 5. 恢复模式

### 5.1 覆盖模式 (Overwrite)

- 清空所有现有数据
- 将备份数据完整写入
- 适用于：换机恢复、全量回退

```dart
Future<void> _restoreOverwrite(BackupData data) async {
  await db.transaction(() async {
    // 清空
    await db.delete(db.topicRows).go();
    await db.delete(db.messageRows).go();
    await db.delete(db.messageBlockRows).go();
    await db.delete(db.assistantRows).go();
    await db.delete(db.providerRows).go();
    await db.delete(db.groupRows).go();
    await db.delete(db.appSettingRows).go();
    // 写入
    await _insertAll(data);
  });
}
```

### 5.2 合并模式 (Merge)

- 不清空现有数据
- 按 ID 去重：已存在的保留本地版本，新增的追加
- 适用于：部分数据导入、多设备同步

```dart
Future<void> _restoreMerge(BackupData data) async {
  await db.transaction(() async {
    for (final topic in data.topics) {
      final existing = await db.topicDao.getById(topic.id);
      if (existing == null) {
        await db.topicDao.upsert(topic);
      }
      // 已存在 → 跳过（保留本地版本）
    }
    // ... 同理处理其他表
  });
}
```

**合并冲突策略**：
- **对话 (Topics)**: 同 ID 保留本地，不同 ID 追加
- **消息 (Messages)**: 跟随对话，若对话存在则跳过其消息
- **助手 (Assistants)**: 同 ID 保留本地，不同 ID 追加
- **供应商 (Providers)**: 同 ID 保留本地（避免覆盖用户新的 API Key）
- **设置 (Settings)**: 保留本地（用户当前的偏好优先）

---

## 6. 安全保障

### 6.1 恢复前自动备份

任何恢复操作前，系统自动创建一份当前数据的本地备份（"安全网备份"），存储在内部目录。如果恢复后用户不满意，可以用这份备份回退。

```
getApplicationDocumentsDirectory()/backups/
├── auto_pre_restore_2026-06-23T15-30-00.zip   ← 恢复前自动创建
├── auto_pre_migrate_2026-06-23T10-00-00.zip   ← schema 升级前自动创建
└── manual_2026-06-22T20-00-00.zip             ← 用户手动备份
```

保留策略：自动备份最多保留 **5 份**，超出后删除最旧的。

### 6.2 事务保护

所有恢复操作在 Drift 事务内执行：

```dart
await db.transaction(() async {
  // 所有写入操作...
  // 如果中途任何操作抛异常 → 整个事务回滚
  // 原数据完全不受影响
});
```

### 6.3 完整性校验

```dart
/// 备份时：计算所有数据文件的 SHA-256
String _computeChecksum(List<File> dataFiles) {
  final digest = sha256.convert(concatenatedBytes);
  return 'sha256:${digest.toString()}';
}

/// 恢复时：验证 checksum 一致
bool _verifyChecksum(Directory extractedDir, String expectedChecksum) {
  final actual = _computeChecksum(dataFiles);
  return actual == expectedChecksum;
}
```

校验失败时：
- 显示警告弹窗："备份文件可能已损坏"
- 提供"仍然恢复"和"取消"两个选项
- 不会静默继续

### 6.4 数据库升级前自动备份

在 `AppDatabase.migration.onUpgrade` 中，执行 schema 迁移前先创建备份：

```dart
onUpgrade: (m, from, to) async {
  // 先备份当前数据
  await BackupService.instance.createAutoBackup(
    reason: 'pre_migrate_v${from}_to_v$to',
  );
  // 再执行迁移
  if (from < 5) { ... }
},
```

### 6.5 API Key 安全

模型供应商数据包含 API Key。备份时的策略：

- **默认**：API Key 原样保存在备份中（用户自己的备份文件）
- **可选**：提供"加密 API Key"选项，使用用户设置的密码 AES-256 加密
- **WebDAV 传输**：建议用户使用 HTTPS 的 WebDAV 服务

---

## 7. 技术架构

### 7.1 目录结构

```
lib/features/backup/
├── domain/
│   ├── backup_manifest.dart          ← BackupManifest 数据模型
│   ├── backup_config.dart            ← WebDavConfig, RestoreMode
│   └── backup_file_item.dart         ← 远程备份文件列表项
├── data/
│   ├── backup_service.dart           ← 核心备份/恢复逻辑
│   ├── webdav_client.dart            ← WebDAV HTTP 操作
│   └── backup_migrator.dart          ← 版本迁移补丁
├── application/
│   ├── backup_controller.dart        ← Riverpod controller
│   └── backup_controller.g.dart
└── presentation/
    ├── backup_settings_page.dart     ← 备份设置主页面
    ├── widgets/
    │   ├── webdav_config_section.dart
    │   ├── local_backup_section.dart
    │   └── remote_file_list_sheet.dart
    └── dialogs/
        ├── restore_confirm_dialog.dart
        └── restore_mode_dialog.dart
```

### 7.2 依赖

```yaml
# pubspec.yaml 新增
dependencies:
  archive: ^4.0.2        # ZIP 压缩/解压
  crypto: ^3.0.6         # SHA-256 checksum
  xml: ^6.5.0            # WebDAV PROPFIND XML 解析
  http: ^1.3.0           # WebDAV HTTP 请求
```

### 7.3 核心类设计

```dart
/// 备份服务 — 负责备份/恢复的核心逻辑
class BackupService {
  final AppDatabase db;
  
  /// 创建备份 ZIP 文件
  Future<File> createBackup({
    bool includeMessages = true,
    bool includeProviders = true,
    bool includeSettings = true,
  });
  
  /// 从 ZIP 文件恢复
  Future<void> restoreFromFile(
    File zipFile, {
    RestoreMode mode = RestoreMode.overwrite,
  });
  
  /// 从 Web 格式 JSON 导入
  Future<void> importFromWebFormat(File jsonFile);
  
  /// 创建自动备份（内部使用）
  Future<void> createAutoBackup({required String reason});
  
  /// 列出本地备份文件
  Future<List<BackupFileItem>> listLocalBackups();
  
  /// 删除本地备份
  Future<void> deleteLocalBackup(String filename);
}

/// WebDAV 客户端
class WebDavClient {
  final WebDavConfig config;
  
  Future<void> testConnection();
  Future<void> ensureCollection();
  Future<void> upload(File file);
  Future<List<BackupFileItem>> listFiles();
  Future<File> download(BackupFileItem item);
  Future<void> delete(BackupFileItem item);
}

/// 版本迁移器
class BackupMigrator {
  /// 将备份数据从 sourceSchema 迁移到当前 schema
  BackupData migrate(BackupData data, int sourceSchema);
}
```

### 7.4 Riverpod 集成

```dart
@riverpod
class BackupController extends _$BackupController {
  @override
  BackupState build() => const BackupState.idle();
  
  Future<void> backup();
  Future<void> restoreFromLocal(File file, RestoreMode mode);
  Future<void> backupToWebDav();
  Future<void> restoreFromWebDav(BackupFileItem item, RestoreMode mode);
  Future<void> testWebDavConnection();
}

@freezed
class BackupState with _$BackupState {
  const factory BackupState.idle() = _Idle;
  const factory BackupState.working({required String message}) = _Working;
  const factory BackupState.success({required String message}) = _Success;
  const factory BackupState.error({required String message}) = _Error;
}
```

---

## 8. UI 设计

### 8.1 备份设置页面结构

```
备份与恢复
├── [Section] 备份管理
│   ├── [Switch] 包含聊天记录
│   ├── [Switch] 包含模型供应商配置
│   └── [Switch] 包含应用设置
│
├── [Section] 本地备份
│   ├── [Button] 创建备份 → 生成 ZIP → 分享
│   ├── [Button] 从文件恢复 → 文件选择器 → 确认弹窗
│   └── [List]   本地备份历史（自动备份 + 手动备份）
│
├── [Section] WebDAV 云备份
│   ├── [Input]  服务器地址
│   ├── [Input]  用户名
│   ├── [Input]  密码
│   ├── [Input]  备份路径 (默认: aetherlink_backups)
│   ├── [Button] 测试连接
│   ├── [Button] 备份到 WebDAV
│   └── [Button] 从 WebDAV 恢复 → 文件列表 → 选择 → 确认
│
└── [Section] 导入
    ├── [Button] 从 Web 版导入 (JSON)
    └── [Button] 从其他应用导入 (第三期)
```

### 8.2 恢复确认弹窗

```
┌─────────────────────────────────────┐
│           确认恢复数据？             │
├─────────────────────────────────────┤
│                                     │
│  备份信息:                          │
│  • 创建时间: 2026-06-23 15:30       │
│  • 来源设备: Xiaomi 14 Pro          │
│  • 数据版本: v4                     │
│  • 对话数: 42                       │
│  • 消息数: 1,280                    │
│  • 助手数: 5                        │
│                                     │
│  恢复模式:                          │
│  ┌─────────────────────────────┐    │
│  │ ○ 覆盖模式                  │    │
│  │   清空当前数据，完整恢复     │    │
│  ├─────────────────────────────┤    │
│  │ ○ 合并模式                  │    │
│  │   保留当前数据，追加新内容   │    │
│  └─────────────────────────────┘    │
│                                     │
│  ⚠️ 恢复前会自动备份当前数据        │
│                                     │
├─────────────────────────────────────┤
│      [取消]            [确认恢复]    │
└─────────────────────────────────────┘
```

---

## 9. 错误处理

### 9.1 错误类型与用户反馈

| 错误场景 | 用户提示 | 技术处理 |
|---------|---------|---------|
| ZIP 解压失败 | "备份文件已损坏，无法读取" | 不进入恢复流程 |
| Checksum 不匹配 | "文件可能已被修改或传输中损坏" | 允许用户选择强制恢复 |
| Schema 版本过高 | "此备份来自更高版本的 app，部分数据可能无法完全恢复" | 警告但允许继续 |
| 事务写入失败 | "恢复失败，您的原有数据未受影响" | 自动回滚 |
| WebDAV 连接失败 | "无法连接到服务器，请检查地址和凭据" | 显示 HTTP 状态码 |
| WebDAV 上传失败 | "上传失败 (HTTP {code})，请检查存储空间" | 清理临时文件 |
| 存储空间不足 | "存储空间不足，需要约 {size}MB 可用空间" | 备份前预检查 |

### 9.2 日志

关键操作记录日志（使用现有 Logger 基础设施），包括：
- 备份创建时间、大小、耗时
- 恢复开始/完成/失败
- WebDAV 请求/响应状态
- 版本迁移应用记录

---

## 10. 性能考虑

### 10.1 大数据量处理

- **ZIP 压缩在 Isolate 中执行**（同 kelivo），不阻塞 UI
- **JSON 序列化流式写入**：数据量大时不一次性拼接字符串
- **WebDAV 流式上传/下载**：使用 `StreamedRequest`，不将整个文件载入内存

### 10.2 预估性能

| 数据规模 | ZIP 大小 | 备份耗时 | 恢复耗时 |
|---------|---------|---------|---------|
| 100 对话 / 3000 消息 | ~2MB | <2s | <1s |
| 500 对话 / 15000 消息 | ~10MB | <5s | <3s |
| 2000 对话 / 60000 消息 | ~40MB | <15s | <10s |

### 10.3 内存优化

- 备份时分表读取，每表序列化后立即写入临时文件，释放内存
- 不将整个数据库 dump 到单个巨型 Map 中

---

## 11. 第一期交付范围

### 包含

- [x] 备份数据模型 (manifest, config)
- [x] 本地 ZIP 备份（生成 + 分享）
- [x] 本地恢复（从文件选择器导入）
- [x] 覆盖模式和合并模式
- [x] 恢复前自动备份（安全网）
- [x] Checksum 完整性校验
- [x] 版本兼容迁移框架
- [x] WebDAV 配置/测试/备份/恢复/列表
- [x] 备份设置 UI 页面
- [x] 集成到设置页面入口

### 不包含（后续迭代）

- [ ] S3 云存储（第二期）
- [ ] 备份提醒/定期自动备份（第二期）
- [ ] 选择性备份（细粒度选择数据类别，第二期）
- [ ] 导入 Cherry Studio / ChatboxAI 数据（第三期）
- [ ] Web 格式双向兼容导出（第三期）
- [ ] API Key 加密（第三期）
- [ ] 数据库诊断工具（第三期）

---

## 12. 测试策略

### 12.1 单元测试

- `BackupService.createBackup()` — 验证 ZIP 结构和 manifest 正确
- `BackupService.restoreFromFile()` — 覆盖模式和合并模式分别测试
- `BackupMigrator.migrate()` — 各 schema 版本升级路径
- `WebDavClient` — Mock HTTP 验证请求格式

### 12.2 集成测试

- 完整备份 → 恢复 → 验证数据一致
- 模拟中途崩溃（transaction 回滚）
- 大数据量压力测试

### 12.3 兼容性测试

- 使用旧版 schema 创建的备份文件恢复到新版
- 验证 Web 版备份 JSON 能被正确导入

---

## 13. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| Drift 事务在大批量写入时超时 | 恢复失败 | 分批写入，每批 500 条，仍在同一事务内 |
| 用户 WebDAV 服务器不标准 | 部分操作失败 | 宽松解析 XML 响应，兼容常见服务器差异 |
| 备份文件被第三方修改 | 恢复出错误数据 | Checksum 校验 + 用户确认弹窗 |
| 设备存储满 | 备份失败 | 预检查可用空间，不足时提示 |
| JSON 序列化格式随 freezed 升级变化 | 旧备份无法解析 | 手写 fromJson 而非依赖 code-gen，保证格式稳定 |

---

## 附录 A: 与 Web 版 backupUtils.ts 的字段映射

| Web 字段 | Flutter 对应 |
|---------|-------------|
| `topics` | TopicRows.data (Topic JSON) |
| `topics[].messages` | MessageRows (按 topicId 关联) |
| `assistants` | AssistantRows.data (Assistant JSON) |
| `settings` | AppSettingRows (key-value) |
| `modelConfig.providers` | ProviderRows.data (ModelProvider JSON) |
| `localStorage.*` | AppSettingRows (合并到 key-value 存储) |

---

## 附录 B: WebDAV 协议要求

最低兼容 WebDAV Class 1：
- `PROPFIND` (depth 0/1) — 列出文件
- `MKCOL` — 创建备份目录
- `PUT` — 上传备份文件
- `GET` — 下载备份文件
- `DELETE` — 删除远程备份

认证方式：HTTP Basic Auth（base64 编码 username:password）

已验证兼容的服务：
- Nextcloud
- Synology WebDAV
- 坚果云
- InfiniCLOUD
- Alist
