class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
  String? get route => data['route'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: map['read_at'] == null
          ? null
          : DateTime.parse(map['read_at'] as String),
    );
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.messageRequests = true,
    this.messages = true,
    this.connections = true,
    this.studies = true,
  });

  final bool messageRequests;
  final bool messages;
  final bool connections;
  final bool studies;

  NotificationPreferences copyWith({
    bool? messageRequests,
    bool? messages,
    bool? connections,
    bool? studies,
  }) {
    return NotificationPreferences(
      messageRequests: messageRequests ?? this.messageRequests,
      messages: messages ?? this.messages,
      connections: connections ?? this.connections,
      studies: studies ?? this.studies,
    );
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      messageRequests: (map['message_requests'] as bool?) ?? true,
      messages: (map['messages'] as bool?) ?? true,
      connections: (map['connections'] as bool?) ?? true,
      studies: (map['studies'] as bool?) ?? true,
    );
  }
}
