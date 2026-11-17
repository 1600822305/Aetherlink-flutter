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

  bool get isImage => mimeType.startsWith('image/');
  bool get isChat => id.startsWith('block:');
  bool get canDelete => !isInUse && id.startsWith('disk:');
  String get status => isChat
      ? '对话：${topicTitle ?? '未关联话题'}'
      : isInUse ? '使用中' : '未使用';
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
