import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../domain/moderation_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(Supabase.instance.client),
);

final moderationServiceProvider = Provider<ModerationService>(
  (ref) => ModerationService(),
);

final conversationsProvider =
    StreamProvider.autoDispose<List<ConversationSummary>>((ref) {
      final repository = ref.read(chatRepositoryProvider);
      final client = Supabase.instance.client;
      final controller = StreamController<List<ConversationSummary>>();
      var disposed = false;

      Future<void> refresh() async {
        try {
          final data = await repository.fetchConversations();
          if (!disposed) controller.add(data);
        } catch (error, stack) {
          if (!disposed) controller.addError(error, stack);
        }
      }

      refresh();
      final messagesSubscription = client
          .from('messages')
          .stream(primaryKey: ['id'])
          .listen((_) => refresh());
      final conversationsSubscription = client
          .from('conversations')
          .stream(primaryKey: ['id'])
          .listen((_) => refresh());

      ref.onDispose(() {
        disposed = true;
        messagesSubscription.cancel();
        conversationsSubscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, conversationId) =>
          ref.read(chatRepositoryProvider).streamMessages(conversationId),
    );
