import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_models.dart';

class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  Future<List<FeedPost>> fetchPosts() async {
    final currentUser = _client.auth.currentUser;
    final rows = await _client
        .from('posts')
        .select('id, user_id, content, created_at')
        .order('created_at', ascending: false)
        .limit(50);

    final posts = (rows as List).cast<Map<String, dynamic>>();
    if (posts.isEmpty) return [];

    final ids = posts.map((p) => p['id'] as String).toList();
    final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();

    final profileRows = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', userIds);
    final names = <String, String>{
      for (final p in (profileRows as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };

    final likeRows = await _client
        .from('likes')
        .select('post_id, user_id')
        .inFilter('post_id', ids);
    final commentRows = await _client
        .from('comments')
        .select('post_id')
        .inFilter('post_id', ids);

    final likeCount = <String, int>{};
    final likedByMe = <String, bool>{};
    for (final row in (likeRows as List)) {
      final postId = row['post_id'] as String;
      likeCount[postId] = (likeCount[postId] ?? 0) + 1;
      if (row['user_id'] == currentUser?.id) likedByMe[postId] = true;
    }
    final commentCount = <String, int>{};
    for (final row in (commentRows as List)) {
      final postId = row['post_id'] as String;
      commentCount[postId] = (commentCount[postId] ?? 0) + 1;
    }

    return posts.map((p) {
      final id = p['id'] as String;
      return FeedPost(
        id: id,
        userId: p['user_id'] as String,
        content: p['content'] as String,
        createdAt: DateTime.parse(p['created_at'] as String),
        authorName: names[p['user_id'] as String] ?? 'Estudante UFV',
        likeCount: likeCount[id] ?? 0,
        commentCount: commentCount[id] ?? 0,
        likedByMe: likedByMe[id] ?? false,
      );
    }).toList();
  }

  Future<void> createPost(String content) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('posts').insert({
      'user_id': user.id,
      'content': content.trim(),
    });
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

  Future<List<FeedComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('id, user_id, content, created_at')
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
    final names = <String, String>{
      for (final p in (profileRows as List))
        p['id'] as String: (p['display_name'] as String?) ?? 'Estudante UFV',
    };

    return comments.map((c) {
      return FeedComment(
        id: c['id'] as String,
        userId: c['user_id'] as String,
        content: c['content'] as String,
        createdAt: DateTime.parse(c['created_at'] as String),
        authorName: names[c['user_id'] as String] ?? 'Estudante UFV',
      );
    }).toList();
  }

  Future<void> addComment(String postId, String content) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content.trim(),
    });
  }
}
