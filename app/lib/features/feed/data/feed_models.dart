class FeedTopic {
  const FeedTopic({required this.id, required this.label, required this.kind});

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
    this.postId,
    this.authorName = '',
    this.content = '',
  });

  final bool available;
  final String? postId;
  final String authorName;
  final String content;
}

class FeedMedia {
  const FeedMedia({
    required this.id,
    required this.path,
    required this.kind,
    this.altText,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String path;
  final String kind;
  final String? altText;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get isVideo => kind == 'video';
}

class FeedMediaDraft {
  const FeedMediaDraft({
    required this.path,
    required this.kind,
    required this.mimeType,
    required this.byteSize,
    this.width,
    this.height,
    this.durationMs,
    this.altText,
    this.position = 0,
  });

  final String path;
  final String kind;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? altText;
  final int position;

  FeedMediaDraft copyWith({
    String? altText,
    int? position,
    bool clearAlt = false,
  }) {
    return FeedMediaDraft(
      path: path,
      kind: kind,
      mimeType: mimeType,
      byteSize: byteSize,
      width: width,
      height: height,
      durationMs: durationMs,
      altText: clearAlt ? null : (altText ?? this.altText),
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'kind': kind,
      'mime_type': mimeType,
      'byte_size': byteSize,
      'width': width,
      'height': height,
      'duration_ms': durationMs,
      'alt_text': altText,
      'position': position,
    };
  }

  factory FeedMediaDraft.fromMap(Map<String, dynamic> map) {
    return FeedMediaDraft(
      path: map['path'] as String,
      kind: (map['kind'] as String?) ?? 'image',
      mimeType: (map['mime_type'] as String?) ?? 'image/webp',
      byteSize: (map['byte_size'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      durationMs: (map['duration_ms'] as num?)?.toInt(),
      altText: map['alt_text'] as String?,
      position: (map['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeedPollOption {
  const FeedPollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  final String id;
  final String label;
  final int votes;
}

class FeedPoll {
  const FeedPoll({
    required this.id,
    required this.expiresAt,
    required this.options,
    this.myOptionId,
  });

  final String id;
  final DateTime expiresAt;
  final List<FeedPollOption> options;
  final String? myOptionId;

  bool get isClosed => expiresAt.isBefore(DateTime.now());

  int get totalVotes =>
      options.fold(0, (total, option) => total + option.votes);
}

class FeedMention {
  const FeedMention({required this.userId, required this.displayName});

  final String userId;
  final String displayName;
}

class CustomFeed {
  const CustomFeed({
    required this.id,
    required this.name,
    required this.topicIds,
  });

  final String id;
  final String name;
  final List<String> topicIds;
}

class CommentSearchResult {
  const CommentSearchResult({
    required this.commentId,
    required this.postId,
    required this.comment,
    required this.authorName,
    required this.postContent,
    required this.postAuthorName,
  });

  final String commentId;
  final String postId;
  final String comment;
  final String authorName;
  final String postContent;
  final String postAuthorName;
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
    this.replyPolicy = 'anyone',
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
    this.repostOfId,
    this.wasRepost = false,
    this.repostOf,
    this.topics = const [],
    this.media = const [],
    this.poll,
    this.mentions = const [],
    this.bookmarked = false,
    this.editedAt,
    this.pinnedAt,
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
  final String replyPolicy;
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
  final String? repostOfId;
  final bool wasRepost;
  final FeedQuotedPost? repostOf;
  final List<FeedTopic> topics;
  final List<FeedMedia> media;
  final FeedPoll? poll;
  final List<FeedMention> mentions;
  final bool bookmarked;
  final DateTime? editedAt;
  final DateTime? pinnedAt;
  final String? source;
  final bool courseMatch;
  final bool campusMatch;
  final bool interestMatch;

  FeedPost copyWith({int? likeCount, bool? likedByMe, bool? bookmarked}) {
    return FeedPost(
      id: id,
      userId: userId,
      content: content,
      createdAt: createdAt,
      authorName: authorName,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      visibility: visibility,
      replyPolicy: replyPolicy,
      avatarPath: avatarPath,
      groupId: groupId,
      groupName: groupName,
      groupOfficial: groupOfficial,
      postedAsGroup: postedAsGroup,
      roleId: roleId,
      roleNameSnapshot: roleNameSnapshot,
      roleCurrent: roleCurrent,
      quotedPostId: quotedPostId,
      wasQuote: wasQuote,
      quoted: quoted,
      repostOfId: repostOfId,
      wasRepost: wasRepost,
      repostOf: repostOf,
      topics: topics,
      media: media,
      poll: poll,
      mentions: mentions,
      bookmarked: bookmarked ?? this.bookmarked,
      editedAt: editedAt,
      pinnedAt: pinnedAt,
      source: source,
      courseMatch: courseMatch,
      campusMatch: campusMatch,
      interestMatch: interestMatch,
    );
  }
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
