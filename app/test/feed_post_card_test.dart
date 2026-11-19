import 'package:conexa/features/feed/data/feed_models.dart';
import 'package:conexa/features/feed/presentation/feed_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('post usa balão de comentário e não repete o nome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final post = FeedPost(
      id: 'post-1',
      userId: 'user-1',
      content: 'Publicação de teste',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      authorName: 'Revisor Conexa B',
      likeCount: 2,
      commentCount: 1,
      likedByMe: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FeedPostCard(
              post: post,
              onLike: () {},
              onComment: () {},
              onRepost: () {},
              onBookmark: () {},
              onCopyLink: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisor Conexa B'), findsOneWidget);
    expect(find.byTooltip('Responder'), findsOneWidget);
    expect(find.byTooltip('Republicar'), findsOneWidget);
    expect(find.byTooltip('Curtir'), findsOneWidget);
    expect(find.byTooltip('Salvar'), findsOneWidget);
    expect(find.byTooltip('Compartilhar'), findsOneWidget);
    expect(find.byTooltip('Mais opções'), findsOneWidget);
  });
}
