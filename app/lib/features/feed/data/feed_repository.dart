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
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
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
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
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
          'id, user_id, content, created_at, visibility, group_id, role_id, '
          'role_name_snapshot, posted_as_group, quoted_post_id, was_quote',
        )
        .inFilter('id', ids);
    final posts = (postRows as List).cast<Map<String, dynamic>>();
    if (posts.isEmpty) return [];

    final userIds = posts
        .map((p) => p['user_id'] as String)
        .toSet()
        .toList();
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

    final names = <String, String>{};
    final avatars = <String, String?>{};
    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name, avatar_url')
        .inFilter('id', userIds);
    for (final p in (profileRows as List)) {
      names[p['id'] as String] = (p['display_name'] as String?) ?? 'Estudante UFV';
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
    final ptList = (await _client
            .from('post_topics')
            .select('post_id, topic_id')
            .inFilter('post_id', ids) as List)
        .cast<Map<String, dynamic>>();
    if (ptList.isNotEmpty) {
      final topicIds = ptList.map((r) => r['topic_id'] as String).toSet().toList();
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
    if (quotedIds.isNotEmpty) {
      final qList = (await _client
              .from('posts')
              .select('id, user_id, content')
              .inFilter('id', quotedIds) as List)
          .cast<Map<String, dynamic>>();
      final qUserIds = qList.map((q) => q['user_id'] as String).toSet().toList();
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
          authorName: qNames[q['user_id'] as String] ?? 'Estudante UFV',
          content: q['content'] as String,
        );
      }
    }

    return posts.map((p) {
      final id = p['id'] as String;
      final userId = p['user_id'] as String;
      final roleId = p['role_id'] as String?;
      final quotedId = p['quoted_post_id'] as String?;
      final wasQuote = p['was_quote'] == true;

      FeedQuotedPost? quoted;
      if (wasQuote && quotedId == null) {
        quoted = const FeedQuotedPost(available: false);
      } else if (quotedId != null) {
        quoted = quotedMap[quotedId] ?? const FeedQuotedPost(available: false);
      }

      return FeedPost(
        id: id,
        userId: userId,
        content: p['content'] as String,
        createdAt: DateTime.parse(p['created_at'] as String),
        visibility: (p['visibility'] as String?) ?? 'public',
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
        topics: topicsByPost[id] ?? const [],
        source: sourceByPost[id],
        courseMatch: courseMatch[id] ?? false,
        campusMatch: campusMatch[id] ?? false,
        interestMatch: interestMatch[id] ?? false,
      );
    }).toList();
  }

  Future<void> createPost(
    String content, {
    String visibility = 'public',
    List<String> topicIds = const [],
    String? groupId,
    String? roleId,
    bool postedAsGroup = false,
    String? quotedPostId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final row = <String, dynamic>{
      'id': uuidV4(),
      'user_id': user.id,
      'content': content.trim(),
      'visibility': groupId != null ? 'public' : visibility,
      'posted_as_group': postedAsGroup,
    };
    if (groupId != null) row['group_id'] = groupId;
    if (roleId != null) row['role_id'] = roleId;
    if (quotedPostId != null) row['quoted_post_id'] = quotedPostId;

    final postId = row['id'] as String;
    await _client.from('posts').insert(row);

    for (final topicId in topicIds) {
      try {
        await _client
            .from('post_topics')
            .insert({'post_id': postId, 'topic_id': topicId});
      } catch (_) {
        // topico opcional; nao derruba a publicacao
      }
    }
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

    final userIds = comments.map((c) => c['user_id'] as String).toSet().toList();
    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds);
    final names = <String, String>{};
    for (final p in (profileRows as List)) {
      names[p['id'] as String] = (p['display_name'] as String?) ?? 'Estudante UFV';
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

  Future<void> addComment(String postId, String content, {String? parentId}) async {
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
