class FeedPost {
  const FeedPost({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.visibility = 'public',
    this.avatarPath,
  });

  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String authorName;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final String visibility;
  final String? avatarPath;
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.authorName,
  });

  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String authorName;
}
