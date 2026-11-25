enum StorageMediaFilter { all, chat, tools, avatars }
enum StorageMediaSort { newest, oldest, largest, smallest }

class StorageMedia {
  const StorageMedia({
    required this.id,
    required this.name,
    required this.source,
    required this.mimeType,
    required this.bytes,
    required this.modifiedAt,
    required this.filter,
    required this.isInUse,
    this.topicId,
    this.topicTitle,
    this.assistantId,
    this.isInline = false,
    this.usagePending = false,
  });

  final String id;
  final String name;
  final String source;
  final String mimeType;
  final int bytes;
  final DateTime modifiedAt;
  final StorageMediaFilter filter;
  final bool isInUse;
  final bool isInline;
  final String? topicId;
  final String? topicTitle;
  final String? assistantId;

  /// 磁盘文件的「是否在用」还在后台核对中：此时不可勾选删除。
  final bool usagePending;

  bool get isImage => mimeType.startsWith('image/');
  bool get isChat => id.startsWith('block:');
  bool get canDelete => !usagePending && !isInUse && id.startsWith('disk:');
  String get status => isChat
      ? '对话：${topicTitle ?? '未关联话题'}'
      : usagePending ? '检查中…' : isInUse ? '使用中' : '未使用';

  StorageMedia copyWith({bool? isInUse, bool? usagePending}) => StorageMedia(
    id: id, name: name, source: source, mimeType: mimeType, bytes: bytes,
    modifiedAt: modifiedAt, filter: filter,
    isInUse: isInUse ?? this.isInUse,
    topicId: topicId, topicTitle: topicTitle, assistantId: assistantId,
    isInline: isInline,
    usagePending: usagePending ?? this.usagePending,
  );

  Map<String, Object?> toJson() => {
    'id': id, 'name': name, 'source': source, 'mime': mimeType, 'bytes': bytes,
    'mtime': modifiedAt.millisecondsSinceEpoch, 'filter': filter.name,
    'inUse': isInUse, 'inline': isInline, 'topicId': topicId,
    'topicTitle': topicTitle, 'assistantId': assistantId,
  };

  static StorageMedia fromJson(Map<String, Object?> j) => StorageMedia(
    id: j['id']! as String, name: j['name']! as String,
    source: j['source']! as String, mimeType: j['mime']! as String,
    bytes: (j['bytes']! as num).toInt(),
    modifiedAt: DateTime.fromMillisecondsSinceEpoch((j['mtime']! as num).toInt()),
    filter: StorageMediaFilter.values.byName(j['filter']! as String),
    isInUse: j['inUse']! as bool, isInline: j['inline'] as bool? ?? false,
    topicId: j['topicId'] as String?, topicTitle: j['topicTitle'] as String?,
    assistantId: j['assistantId'] as String?,
  );
}

List<StorageMedia> visibleStorageMedia(
  Iterable<StorageMedia> items, {
  required bool isImageView,
  StorageMediaFilter filter = StorageMediaFilter.all,
  StorageMediaSort sort = StorageMediaSort.newest,
}) {
  final result = items.where((item) => item.isImage == isImageView &&
      (filter == StorageMediaFilter.all || item.filter == filter)).toList();
  result.sort((a, b) {
    final order = switch (isImageView ? sort : StorageMediaSort.newest) {
      StorageMediaSort.newest => b.modifiedAt.compareTo(a.modifiedAt),
      StorageMediaSort.oldest => a.modifiedAt.compareTo(b.modifiedAt),
      StorageMediaSort.largest => b.bytes.compareTo(a.bytes),
      StorageMediaSort.smallest => a.bytes.compareTo(b.bytes),
    };
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
  return result;
}

class StorageMediaDeletion {
  const StorageMediaDeletion({required this.deleted, required this.kept});
  final int deleted;
  final int kept;
}
