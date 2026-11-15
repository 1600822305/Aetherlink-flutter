class TopicStorageUsage {
  const TopicStorageUsage({
    required this.id,
    required this.title,
    required this.assistantName,
    required this.bytes,
    required this.messageCount,
    required this.imageCount,
    required this.videoCount,
  });

  final String id;
  final String title;
  final String assistantName;
  final int bytes;
  final int messageCount;
  final int imageCount;
  final int videoCount;
}
