import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';
import 'feed_models.dart';

class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchForYou() async {
    final rows = await _client.rpc(
      'feed_for_you',
      params: {'p_limit': 30, 'p_offset': 0},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];

    final ids = list.map((r) => r['post_id'] as String).toList();
    final course = <String, bool>{};
    final campus = <String, bool>{};
    final interest = <String, bool>{};
    for (final r in list) {
      final id = r['post_id'] as String;
      course[id] = r['course_match'] == true;
      campus[id] = r['campus_match'] == true;
      interest[id] = r['interest_match'] == true;
    }

    final byId = {
      for (final p in await _fetchByIds(
        ids,
        courseMatch: course,
        campusMatch: campus,
        interestMatch: interest,
      ))
        p.id: p,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<FeedPost>> fetchConnections() async {
    final rows = await _client.rpc(
      'feed_connections',
      params: {'p_limit': 30, 'p_offset': 0},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];

    final ids = list.map((r) => r['post_id'] as String).toList();
    final source = <String, String>{
      for (final r in list) r['post_id'] as String: r['source'] as String,
    };

    final byId = {
      for (final p in await _fetchByIds(ids, sourceByPost: source)) p.id: p,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<FeedPost>> _fetchByIds(
    List<String> ids, {
    Map<String, String> sourceByPost = const {},
    Map<String, bool> courseMatch = const {},
    Map<String, bool> campusMatch = const {},
    Map<String, bool> interestMatch = const {},
  }) async {
    if (ids.isEmpty) return [];
    final currentUser = _client.auth.currentUser;

    final postRows = await _client
        .from('posts')
        .select(
          'id, user_id, content, created_at, visibility, reply_policy, '
          'group_id, role_id, role_name_snapshot, posted_as_group, '
          'quoted_post_id, was_quote, repost_of_id, was_repost, '
          'edited_at, pinned_at',
        )
        .inFilter('id', ids);
    final posts = (postRows as List).cast<Map<String, dynamic>>();
    if (posts.isEmpty) return [];

    final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
    final groupIds = posts
        .where((p) => p['group_id'] != null)
        .map((p) => p['group_id'] as String)
        .toSet()
        .toList();
    final roleIds = posts
        .where((p) => p['role_id'] != null)
        .map((p) => p['role_id'] as String)
        .toSet()
        .toList();
    final quotedIds = posts
        .where((p) => p['quoted_post_id'] != null)
        .map((p) => p['quoted_post_id'] as String)
        .toSet()
        .toList();
    final repostIds = posts
        .where((p) => p['repost_of_id'] != null)
        .map((p) => p['repost_of_id'] as String)
        .toSet()
        .toList();

    final names = <String, String>{};
    final avatars = <String, String?>{};
    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name, avatar_url')
        .inFilter('id', userIds);
    for (final p in (profileRows as List)) {
      names[p['id'] as String] =
          (p['display_name'] as String?) ?? 'Estudante UFV';
      avatars[p['id'] as String] = p['avatar_url'] as String?;
    }

    final groupMap = <String, Map<String, dynamic>>{};
    if (groupIds.isNotEmpty) {
      final groupRows = await _client
          .from('groups')
          .select('id, name, is_official')
          .inFilter('id', groupIds);
      for (final g in (groupRows as List)) {
        groupMap[g['id'] as String] = g as Map<String, dynamic>;
      }
    }

    final assigned = <String, bool>{};
    if (roleIds.isNotEmpty) {
      final mrRows = await _client
          .from('group_member_roles')
          .select('user_id, role_id')
          .inFilter('role_id', roleIds);
      for (final r in (mrRows as List)) {
        assigned['${r['user_id']}|${r['role_id']}'] = true;
      }
    }

    final topicMap = <String, FeedTopic>{};
    final topicsByPost = <String, List<FeedTopic>>{};
    final ptList =
        (await _client
                    .from('post_topics')
                    .select('post_id, topic_id')
                    .inFilter('post_id', ids)
                as List)
            .cast<Map<String, dynamic>>();
    if (ptList.isNotEmpty) {
      final topicIds = ptList
          .map((r) => r['topic_id'] as String)
          .toSet()
          .toList();
      final topicRows = await _client
          .from('topics')
          .select('id, label, kind')
          .inFilter('id', topicIds);
      for (final t in (topicRows as List)) {
        topicMap[t['id'] as String] = FeedTopic(
          id: t['id'] as String,
          label: t['label'] as String,
          kind: t['kind'] as String,
        );
      }
      for (final r in ptList) {
        final topic = topicMap[r['topic_id'] as String];
        if (topic != null) {
          topicsByPost.putIfAbsent(r['post_id'] as String, () => []).add(topic);
        }
      }
    }

    final likeCount = <String, int>{};
    final likedByMe = <String, bool>{};
    final likeRows = await _client
        .from('likes')
        .select('post_id, user_id')
        .inFilter('post_id', ids);
    for (final r in (likeRows as List)) {
      final pid = r['post_id'] as String;
      likeCount[pid] = (likeCount[pid] ?? 0) + 1;
      if (r['user_id'] == currentUser?.id) likedByMe[pid] = true;
    }
    final commentCount = <String, int>{};
    final commentRows = await _client
        .from('comments')
        .select('post_id')
        .inFilter('post_id', ids);
    for (final r in (commentRows as List)) {
      final pid = r['post_id'] as String;
      commentCount[pid] = (commentCount[pid] ?? 0) + 1;
    }

    final quotedMap = <String, FeedQuotedPost>{};
    final referencedIds = {...quotedIds, ...repostIds}.toList();
    if (referencedIds.isNotEmpty) {
      final qList =
          (await _client
                      .from('posts')
                      .select('id, user_id, content')
                      .inFilter('id', referencedIds)
                      .isFilter('hidden_at', null)
                  as List)
              .cast<Map<String, dynamic>>();
      final qUserIds = qList
          .map((q) => q['user_id'] as String)
          .toSet()
          .toList();
      final qNames = <String, String>{};
      if (qUserIds.isNotEmpty) {
        final qProfiles = await _client
            .from('profiles_public')
            .select('id, display_name')
            .inFilter('id', qUserIds);
        for (final p in (qProfiles as List)) {
          qNames[p['id'] as String] =
              (p['display_name'] as String?) ?? 'Estudante UFV';
        }
      }
      for (final q in qList) {
        quotedMap[q['id'] as String] = FeedQuotedPost(
          available: true,
          postId: q['id'] as String,
          authorName: qNames[q['user_id'] as String] ?? 'Estudante UFV',
          content: q['content'] as String,
        );
      }
    }

    final bookmarkedByMe = <String>{};
    if (currentUser != null) {
      final bookmarkRows = await _client
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', currentUser.id)
          .inFilter('post_id', ids);
      for (final row in (bookmarkRows as List)) {
        bookmarkedByMe.add(row['post_id'] as String);
      }
    }

    final mediaByPost = <String, List<FeedMedia>>{};
    final mediaRows = await _client
        .from('post_media')
        .select(
          'id, post_id, object_key, kind, alt_text, width, height, duration_ms, '
          'position',
        )
        .inFilter('post_id', ids)
        .order('position');
    for (final row in (mediaRows as List)) {
      final pid = row['post_id'] as String;
      mediaByPost
          .putIfAbsent(pid, () => [])
          .add(
            FeedMedia(
              id: row['id'] as String,
              path: row['object_key'] as String,
              kind: row['kind'] as String,
              altText: row['alt_text'] as String?,
              width: (row['width'] as num?)?.toInt(),
              height: (row['height'] as num?)?.toInt(),
              durationMs: (row['duration_ms'] as num?)?.toInt(),
            ),
          );
    }

    final pollByPost = <String, FeedPoll>{};
    final pollRows = await _client
        .from('polls')
        .select('id, post_id, expires_at')
        .inFilter('post_id', ids);
    final pollIds = (pollRows as List)
        .map((row) => row['id'] as String)
        .toList();
    if (pollIds.isNotEmpty) {
      final optionRows = await _client
          .from('poll_options')
          .select('id, poll_id, label, position')
          .inFilter('poll_id', pollIds)
          .order('position');
      final results = await _client.rpc(
        'poll_results',
        params: {'p_poll_ids': pollIds},
      ) as List;
      final votesByOption = <String, int>{};
      final myVoteByPoll = <String, String>{};
      for (final row in results) {
        final optionId = row['option_id'] as String;
        votesByOption[optionId] = (row['votes'] as num).toInt();
        if (row['my_vote'] == true) {
          myVoteByPoll[row['poll_id'] as String] = optionId;
        }
      }
      final optionsByPoll = <String, List<FeedPollOption>>{};
      for (final row in (optionRows as List)) {
        final optionId = row['id'] as String;
        optionsByPoll
            .putIfAbsent(row['poll_id'] as String, () => [])
            .add(
              FeedPollOption(
                id: optionId,
                label: row['label'] as String,
                votes: votesByOption[optionId] ?? 0,
              ),
            );
      }
      for (final row in (pollRows as List)) {
        final pollId = row['id'] as String;
        pollByPost[row['post_id'] as String] = FeedPoll(
          id: pollId,
          expiresAt: DateTime.parse(row['expires_at'] as String),
          options: optionsByPoll[pollId] ?? const [],
          myOptionId: myVoteByPoll[pollId],
        );
      }
    }

    final mentionsByPost = <String, List<FeedMention>>{};
    final mentionRows = await _client
        .from('post_mentions')
        .select('post_id, user_id')
        .inFilter('post_id', ids);
    final mentionUserIds = (mentionRows as List)
        .map((row) => row['user_id'] as String)
        .toSet()
        .toList();
    final mentionNames = <String, String>{};
    if (mentionUserIds.isNotEmpty) {
      final mentionProfiles = await _client
          .from('profiles_public')
          .select('id, display_name')
          .inFilter('id', mentionUserIds);
      for (final p in (mentionProfiles as List)) {
        mentionNames[p['id'] as String] =
            (p['display_name'] as String?) ?? 'Estudante UFV';
      }
    }
    for (final row in (mentionRows as List)) {
      final userId = row['user_id'] as String;
      mentionsByPost
          .putIfAbsent(row['post_id'] as String, () => [])
          .add(
            FeedMention(
              userId: userId,
              displayName: mentionNames[userId] ?? 'Estudante UFV',
            ),
          );
    }

    return posts.map((p) {
      final id = p['id'] as String;
      final userId = p['user_id'] as String;
      final roleId = p['role_id'] as String?;
      final quotedId = p['quoted_post_id'] as String?;
      final wasQuote = p['was_quote'] == true;
      final repostId = p['repost_of_id'] as String?;
      final wasRepost = p['was_repost'] == true;

      FeedQuotedPost? quoted;
      if (wasQuote && quotedId == null) {
        quoted = const FeedQuotedPost(available: false);
      } else if (quotedId != null) {
        quoted = quotedMap[quotedId] ?? const FeedQuotedPost(available: false);
      }

      FeedQuotedPost? repostOf;
      if (wasRepost && repostId == null) {
        repostOf = const FeedQuotedPost(available: false);
      } else if (repostId != null) {
        repostOf =
            quotedMap[repostId] ?? const FeedQuotedPost(available: false);
      }

      return FeedPost(
        id: id,
        userId: userId,
        content: p['content'] as String,
        createdAt: DateTime.parse(p['created_at'] as String),
        visibility: (p['visibility'] as String?) ?? 'public',
        replyPolicy: (p['reply_policy'] as String?) ?? 'anyone',
        authorName: names[userId] ?? 'Estudante UFV',
        avatarPath: avatars[userId],
        likeCount: likeCount[id] ?? 0,
        commentCount: commentCount[id] ?? 0,
        likedByMe: likedByMe[id] ?? false,
        groupId: p['group_id'] as String?,
        groupName: p['group_id'] != null
            ? (groupMap[p['group_id']]?['name'] as String?)
            : null,
        groupOfficial: p['group_id'] != null
            ? (groupMap[p['group_id']]?['is_official'] == true)
            : false,
        postedAsGroup: p['posted_as_group'] == true,
        roleId: roleId,
        roleNameSnapshot: p['role_name_snapshot'] as String?,
        roleCurrent: roleId != null && assigned.containsKey('$userId|$roleId'),
        quotedPostId: quotedId,
        wasQuote: wasQuote,
        quoted: quoted,
        repostOfId: repostId,
        wasRepost: wasRepost,
        repostOf: repostOf,
        topics: topicsByPost[id] ?? const [],
        media: mediaByPost[id] ?? const [],
        poll: pollByPost[id],
        mentions: mentionsByPost[id] ?? const [],
        bookmarked: bookmarkedByMe.contains(id),
        editedAt: p['edited_at'] == null
            ? null
            : DateTime.parse(p['edited_at'] as String),
        pinnedAt: p['pinned_at'] == null
            ? null
            : DateTime.parse(p['pinned_at'] as String),
        source: sourceByPost[id],
        courseMatch: courseMatch[id] ?? false,
        campusMatch: campusMatch[id] ?? false,
        interestMatch: interestMatch[id] ?? false,
      );
    }).toList();
  }

  Future<String> createPost(
    String content, {
    String visibility = 'public',
    String replyPolicy = 'anyone',
    List<String> topicIds = const [],
    String? groupId,
    String? roleId,
    bool postedAsGroup = false,
    String? quotedPostId,
    String? repostOfId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');

    final postId = uuidV4();
    final row = <String, dynamic>{
      'id': postId,
      'user_id': user.id,
      'content': repostOfId == null ? content.trim() : '',
      'visibility': groupId != null ? 'public' : visibility,
      'reply_policy': replyPolicy,
      'posted_as_group': postedAsGroup,
    };
    if (groupId != null) row['group_id'] = groupId;
    if (roleId != null) row['role_id'] = roleId;
    if (quotedPostId != null) row['quoted_post_id'] = quotedPostId;
    if (repostOfId != null) row['repost_of_id'] = repostOfId;

    await _client.from('posts').insert(row);

    for (final topicId in topicIds) {
      try {
        await _client.from('post_topics').insert({
          'post_id': postId,
          'topic_id': topicId,
        });
      } catch (_) {
        // topico opcional; nao derruba a publicacao
      }
    }
    return postId;
  }

  Future<void> attachMedia(String postId, List<FeedMediaDraft> media) async {
    for (final item in media) {
      await _client.from('post_media').insert({
        'post_id': postId,
        'owner_id': _client.auth.currentUser?.id,
        'object_key': item.path,
        'kind': item.kind,
        'mime_type': item.mimeType,
        'byte_size': item.byteSize,
        'width': item.width,
        'height': item.height,
        'duration_ms': item.durationMs,
        'alt_text': item.altText,
        'position': item.position,
      });
    }
  }

  Future<bool> toggleBookmark(String postId) async {
    final result = await _client.rpc(
      'toggle_bookmark',
      params: {'p_post_id': postId},
    );
    return result is Map && result['bookmarked'] == true;
  }

  Future<List<FeedPost>> fetchBookmarked() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('post_bookmarks')
        .select('post_id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final ids = (rows as List).map((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    final posts = await _fetchByIds(ids);
    final byId = {for (final post in posts) post.id: post};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<FeedPost>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _client.rpc(
      'search_posts',
      params: {'p_query': query.trim(), 'p_limit': 40, 'p_offset': 0},
    ) as List;
    final ids = rows.map((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    return _fetchByIds(ids);
  }

  Future<List<CommentSearchResult>> searchComments(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await _client.rpc(
      'search_comments',
      params: {'p_query': query.trim(), 'p_limit': 40, 'p_offset': 0},
    ) as List;
    if (rows.isEmpty) return [];

    final commentIds = rows.map((r) => r['comment_id'] as String).toList();
    final postIds = rows.map((r) => r['post_id'] as String).toSet().toList();
    final comments = await _client
        .from('comments')
        .select('id, post_id, user_id, content')
        .inFilter('id', commentIds);
    final posts = await _client
        .from('posts')
        .select('id, user_id, content')
        .inFilter('id', postIds);
    final userIds = <String>{
      for (final c in (comments as List)) c['user_id'] as String,
      for (final p in (posts as List)) p['user_id'] as String,
    }.toList();
    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds);
    final names = <String, String>{
      for (final p in (profiles as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };
    final postMap = {for (final p in (posts as List)) p['id'] as String: p};
    final commentMap = {
      for (final c in (comments as List)) c['id'] as String: c,
    };

    return [
      for (final row in rows)
        if (commentMap[row['comment_id']] != null &&
            postMap[row['post_id']] != null)
          CommentSearchResult(
            commentId: row['comment_id'] as String,
            postId: row['post_id'] as String,
            comment:
                (commentMap[row['comment_id']]?['content'] as String?) ?? '',
            authorName:
                names[commentMap[row['comment_id']]?['user_id'] as String] ??
                'Estudante UFV',
            postContent: (postMap[row['post_id']]?['content'] as String?) ?? '',
            postAuthorName:
                names[postMap[row['post_id']]?['user_id'] as String] ??
                'Estudante UFV',
          ),
    ];
  }

  Future<void> recordPostView(String postId) async {
    try {
      await _client.rpc('record_post_view', params: {'p_post_id': postId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> myViewsSummary({int days = 30}) async {
    final result = await _client.rpc(
      'my_views_summary',
      params: {'p_days': days},
    );
    return (result as Map).cast<String, dynamic>();
  }

  Future<List<CustomFeed>> fetchCustomFeeds() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('custom_feeds')
        .select('id, name, topic_ids')
        .eq('user_id', user.id)
        .order('created_at');
    return (rows as List)
        .map(
          (r) => CustomFeed(
            id: r['id'] as String,
            name: r['name'] as String,
            topicIds: (r['topic_ids'] as List? ?? const [])
                .map((e) => e as String)
                .toList(),
          ),
        )
        .toList();
  }

  Future<String> createCustomFeed(String name, List<String> topicIds) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final id = uuidV4();
    await _client.from('custom_feeds').insert({
      'id': id,
      'user_id': user.id,
      'name': name.trim(),
      'topic_ids': topicIds,
    });
    return id;
  }

  Future<void> deleteCustomFeed(String id) async {
    await _client.from('custom_feeds').delete().eq('id', id);
  }

  Future<List<FeedPost>> fetchCustomFeed(String feedId) async {
    final rows = await _client.rpc(
      'feed_custom',
      params: {'p_feed_id': feedId, 'p_limit': 50, 'p_offset': 0},
    ) as List;
    final ids = rows.map((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    return _fetchByIds(ids);
  }

  Future<void> setNotInterested(String postId, bool hidden) async {
    await _client.rpc(
      'set_not_interested',
      params: {'p_post_id': postId, 'p_hidden': hidden},
    );
  }

  Future<List<FeedPost>> fetchNotInterested() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('post_not_interested')
        .select('post_id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final ids = (rows as List).map((r) => r['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    final posts = await _fetchByIds(ids);
    final byId = {for (final post in posts) post.id: post};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<Map<String, dynamic>> myAnalytics({int days = 30}) async {
    final result = await _client.rpc('my_analytics', params: {'p_days': days});
    return (result as Map).cast<String, dynamic>();
  }

  Future<void> editPost(String postId, String content) async {
    await _client.rpc(
      'edit_post',
      params: {'p_post_id': postId, 'p_content': content},
    );
  }

  Future<void> pinPost(String postId, bool pin) async {
    await _client.rpc('pin_post', params: {'p_post_id': postId, 'p_pin': pin});
  }

  Future<void> createPoll(
    String postId,
    List<String> options, {
    int hours = 24,
  }) async {
    await _client.rpc(
      'create_poll',
      params: {'p_post_id': postId, 'p_options': options, 'p_hours': hours},
    );
  }

  Future<void> votePoll(String pollId, String optionId) async {
    await _client.rpc(
      'vote_poll',
      params: {'p_poll_id': pollId, 'p_option_id': optionId},
    );
  }

  Future<void> setPostMentions(String postId, List<String> userIds) async {
    await _client.rpc(
      'set_post_mentions',
      params: {'p_post_id': postId, 'p_user_ids': userIds},
    );
  }

  Future<List<Map<String, dynamic>>> fetchDrafts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('post_drafts')
        .select('id, payload, updated_at')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> saveDraft(
    Map<String, dynamic> payload, {
    String? draftId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final id = draftId ?? uuidV4();
    if (draftId == null) {
      await _client.from('post_drafts').insert({
        'id': id,
        'user_id': user.id,
        'payload': payload,
      });
    } else {
      await _client
          .from('post_drafts')
          .update({
            'payload': payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', draftId)
          .eq('user_id', user.id);
    }
    return id;
  }

  Future<void> deleteDraft(String draftId) async {
    await _client.from('post_drafts').delete().eq('id', draftId);
  }

  Future<List<Map<String, dynamic>>> fetchScheduledPosts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('scheduled_posts')
        .select('id, payload, scheduled_at, status, post_id, error')
        .eq('user_id', user.id)
        .order('scheduled_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> schedulePost(
    Map<String, dynamic> payload,
    DateTime scheduledAt,
  ) async {
    await _client.rpc(
      'schedule_post',
      params: {
        'p_payload': payload,
        'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> cancelScheduledPost(String id) async {
    await _client.rpc('cancel_scheduled_post', params: {'p_id': id});
  }

  Future<void> toggleLike(String postId, bool liked) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (liked) {
      await _client
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } else {
      await _client.from('likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
  }

  Future<List<FeedTopic>> fetchTopics() async {
    final rows = await _client
        .from('topics')
        .select('id, label, kind')
        .eq('is_active', true)
        .order('kind')
        .order('sort_order');
    return (rows as List)
        .map(
          (r) => FeedTopic(
            id: r['id'] as String,
            label: r['label'] as String,
            kind: r['kind'] as String,
          ),
        )
        .toList();
  }

  Future<List<FeedComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('id, post_id, user_id, content, created_at, parent_id, depth')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    final comments = (rows as List).cast<Map<String, dynamic>>();
    if (comments.isEmpty) return [];

    final userIds = comments
        .map((c) => c['user_id'] as String)
        .toSet()
        .toList();
    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds);
    final names = <String, String>{};
    for (final p in (profileRows as List)) {
      names[p['id'] as String] =
          (p['display_name'] as String?) ?? 'Estudante UFV';
    }

    return comments.map((c) {
      return FeedComment(
        id: c['id'] as String,
        postId: c['post_id'] as String,
        userId: c['user_id'] as String,
        content: c['content'] as String,
        createdAt: DateTime.parse(c['created_at'] as String),
        authorName: names[c['user_id'] as String] ?? 'Estudante UFV',
        parentId: c['parent_id'] as String?,
        depth: (c['depth'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? parentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final row = <String, dynamic>{
      'id': uuidV4(),
      'post_id': postId,
      'user_id': user.id,
      'content': content.trim(),
    };
    if (parentId != null) row['parent_id'] = parentId;
    await _client.from('comments').insert(row);
  }
}
