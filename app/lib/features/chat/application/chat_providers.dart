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
    FutureProvider.autoDispose<List<ConversationSummary>>(
      (ref) => ref.read(chatRepositoryProvider).fetchConversations(),
    );

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, conversationId) =>
          ref.read(chatRepositoryProvider).streamMessages(conversationId),
    );
