import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reports/presentation/report_dialog.dart';
import '../application/feed_providers.dart';
import '../data/feed_models.dart';
import 'feed_post_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  bool _comments = false;
  String? _error;
  List<FeedPost> _results = const [];
  List<CommentSearchResult> _commentResults = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _commentResults = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(feedRepositoryProvider);
      if (_comments) {
        final results = await repo.searchComments(query);
        if (mounted) setState(() => _commentResults = results);
      } else {
        final results = await repo.searchPosts(query);
        if (mounted) setState(() => _results = results);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao buscar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar publicacoes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar no feed...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Posts')),
                ButtonSegment(value: true, label: Text('Comentarios')),
              ],
              selected: {_comments},
              onSelectionChanged: (values) {
                setState(() => _comments = values.first);
                _search(_controller.text);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _comments
                ? _buildComments(context, theme)
                : _buildPosts(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts(BuildContext context, ThemeData theme) {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? 'Digite para buscar publicacoes.'
              : 'Nenhuma publicacao encontrada.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final post = _results[index];
        return FeedPostCard(
          post: post,
          onLike: () async {
            try {
              await ref
                  .read(feedRepositoryProvider)
                  .toggleLike(post.id, post.likedByMe);
              _search(_controller.text);
            } catch (_) {}
          },
          onComment: () => context.push('/feed/${post.id}', extra: post),
          onRepost: () => context.push('/feed/compose?quote=1', extra: post),
          onBookmark: () async {
            await ref.read(feedRepositoryProvider).toggleBookmark(post.id);
            _search(_controller.text);
          },
          onReport: () => showReportDialog(
            context,
            ref,
            reportedUserId: post.userId,
            targetType: 'post',
            targetId: post.id,
            contentSnapshot: post.content,
          ),
          onCopyLink: () async {
            await Clipboard.setData(
              ClipboardData(text: 'conexa://feed/${post.id}'),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link da publicacao copiado.')),
              );
            }
          },
          onNotInterested: () async {
            await ref
                .read(feedRepositoryProvider)
                .setNotInterested(post.id, true);
            _search(_controller.text);
          },
        );
      },
    );
  }

  Widget _buildComments(BuildContext context, ThemeData theme) {
    if (_commentResults.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty
              ? 'Digite para buscar comentarios.'
              : 'Nenhum comentario encontrado.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _commentResults.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final item = _commentResults[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.comment, maxLines: 3),
          subtitle: Text(
            '${item.authorName} · em ${item.postAuthorName}: '
            '${item.postContent}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final post = FeedPost(
              id: item.postId,
              userId: '',
              content: item.postContent,
              createdAt: DateTime.now(),
              authorName: item.postAuthorName,
              likeCount: 0,
              commentCount: 0,
              likedByMe: false,
            );
            context.push('/feed/${item.postId}', extra: post);
          },
        );
      },
    );
  }
}
