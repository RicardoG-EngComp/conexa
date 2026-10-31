class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.otherUserId,
    required this.otherName,
    this.lastMessage,
    this.lastAt,
  });

  final String id;
  final String otherUserId;
  final String otherName;
  final String? lastMessage;
  final DateTime? lastAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.flagged,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool flagged;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      flagged: (map['flagged'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
