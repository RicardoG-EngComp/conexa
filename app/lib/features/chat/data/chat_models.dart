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
    this.isGroup = false,
    this.title,
    this.memberCount = 2,
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    this.memberNames = const [],
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
  final bool isGroup;
  final String? title;
  final int memberCount;
  final bool pinned;
  final bool muted;
  final bool archived;
  final List<String> memberNames;

  String get displayName => isGroup ? (title ?? 'Grupo') : otherName;
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
    this.replyToId,
    this.editedAt,
    this.mediaPath,
    this.mediaMime,
    this.mediaBytes,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDurationMs,
    this.mediaName,
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
  final String? replyToId;
  final DateTime? editedAt;
  final String? mediaPath;
  final String? mediaMime;
  final int? mediaBytes;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? mediaDurationMs;
  final String? mediaName;

  bool get hasMedia => mediaPath != null && kind != 'text';

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
      replyToId: map['reply_to_id'] as String?,
      editedAt: map['edited_at'] == null
          ? null
          : DateTime.parse(map['edited_at'] as String),
      mediaPath: map['media_path'] as String?,
      mediaMime: map['media_mime'] as String?,
      mediaBytes: (map['media_bytes'] as num?)?.toInt(),
      mediaWidth: (map['media_width'] as num?)?.toInt(),
      mediaHeight: (map['media_height'] as num?)?.toInt(),
      mediaDurationMs: (map['media_duration_ms'] as num?)?.toInt(),
      mediaName: map['media_name'] as String?,
    );
  }
}

class MessageReaction {
  const MessageReaction({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String userId;
  final String emoji;

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
    );
  }
}

class TypingUser {
  const TypingUser({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

class ChatMember {
  const ChatMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;
}

class ChatMediaDraft {
  const ChatMediaDraft({
    required this.path,
    required this.kind,
    required this.mimeType,
    required this.byteSize,
    this.width,
    this.height,
    this.durationMs,
    this.name,
  });

  final String path;
  final String kind;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? name;
}
