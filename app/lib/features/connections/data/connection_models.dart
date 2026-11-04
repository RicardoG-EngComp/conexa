class ConnectionEntry {
  const ConnectionEntry({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.requesterId,
    this.avatarPath,
  });

  final String userId;
  final String displayName;
  final String status;
  final String requesterId;
  final String? avatarPath;
}

class ConnectionsData {
  const ConnectionsData({
    required this.incoming,
    required this.outgoing,
    required this.accepted,
  });

  final List<ConnectionEntry> incoming;
  final List<ConnectionEntry> outgoing;
  final List<ConnectionEntry> accepted;
}

class ConnectionStatus {
  const ConnectionStatus({required this.status, this.requesterId});

  final String status;
  final String? requesterId;
}
