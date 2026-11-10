class FeedTopic {
  const FeedTopic({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final String kind;

  bool get isCourse => kind == 'course';
  bool get isCampus => kind == 'campus';
  bool get isEvent => kind == 'event_category';
}

class FeedQuotedPost {
  const FeedQuotedPost({
    required this.available,
    this.authorName = '',
    this.content = '',
  });

  final bool available;
  final String authorName;
  final String content;
}

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
    this.groupId,
    this.groupName,
    this.groupOfficial = false,
    this.postedAsGroup = false,
    this.roleId,
    this.roleNameSnapshot,
    this.roleCurrent = false,
    this.quotedPostId,
    this.wasQuote = false,
    this.quoted,
    this.topics = const [],
    this.source,
    this.courseMatch = false,
    this.campusMatch = false,
    this.interestMatch = false,
  });

  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String authorName;
  final String? avatarPath;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final String visibility;
  final String? groupId;
  final String? groupName;
  final bool groupOfficial;
  final bool postedAsGroup;
  final String? roleId;
  final String? roleNameSnapshot;
  final bool roleCurrent;
  final String? quotedPostId;
  final bool wasQuote;
  final FeedQuotedPost? quoted;
  final List<FeedTopic> topics;
  final String? source;
  final bool courseMatch;
  final bool campusMatch;
  final bool interestMatch;
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.authorName,
    this.parentId,
    this.depth = 0,
  });

  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String authorName;
  final String? parentId;
  final int depth;
}
