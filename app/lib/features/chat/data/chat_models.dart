class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherName,
    required this.status,
    this.initiatorId,
    this.requestMessage,
    this.lastMessage,
    this.lastAt,
    this.unreadCount = 0,
  });

  final String id;
  final String otherUserId;
  final String otherName;
  final String status;
  final String? initiatorId;
  final String? requestMessage;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unreadCount;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.flagged,
    required this.createdAt,
    this.kind = 'text',
    this.stickerPath,
    this.gifUrl,
    this.deletedForEveryone = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool flagged;
  final DateTime createdAt;
  final String kind;
  final String? stickerPath;
  final String? gifUrl;
  final bool deletedForEveryone;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: (map['content'] as String?) ?? '',
      flagged: (map['flagged'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      kind: (map['kind'] as String?) ?? 'text',
      stickerPath: map['sticker_path'] as String?,
      gifUrl: map['gif_url'] as String?,
      deletedForEveryone: map['deleted_for_all_at'] != null,
    );
  }
}
