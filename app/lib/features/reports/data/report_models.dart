class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.targetType,
    required this.category,
    required this.status,
    required this.createdAt,
    this.targetId,
    this.description,
    this.contentSnapshot,
    this.actionTaken,
    this.reviewedAt,
  });

  final String id;
  final String reporterId;
  final String reportedUserId;
  final String targetType;
  final String category;
  final String status;
  final DateTime createdAt;
  final String? targetId;
  final String? description;
  final String? contentSnapshot;
  final String? actionTaken;
  final DateTime? reviewedAt;

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as String,
      reporterId: map['reporter_id'] as String,
      reportedUserId: map['reported_user_id'] as String,
      targetType: map['target_type'] as String,
      category: map['category'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      targetId: map['target_id'] as String?,
      description: map['description'] as String?,
      contentSnapshot: map['content_snapshot'] as String?,
      actionTaken: map['action_taken'] as String?,
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.parse(map['reviewed_at'] as String),
    );
  }
}
