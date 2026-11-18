import 'dart:io';

import 'package:conexa/core/utils/uuid.dart';
import 'package:conexa/features/chat/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
  final emailB = Platform.environment['TEST_USER_B_EMAIL'] ?? '';
  final passwordB = Platform.environment['TEST_USER_B_PASSWORD'] ?? '';
  final emailAdmin = Platform.environment['TEST_ADMIN_EMAIL'] ?? '';
  final passwordAdmin = Platform.environment['TEST_ADMIN_PASSWORD'] ?? '';

  Future<void> signInA(SupabaseClient c) =>
      signInWithRetry(c, emailA, passwordA);
  Future<void> signInB(SupabaseClient c) =>
      signInWithRetry(c, emailB, passwordB);
  Future<void> signInAdmin(SupabaseClient c) =>
      signInWithRetry(c, emailAdmin, passwordAdmin);

  Future<void> expectError(
    Future<dynamic> Function() action,
    String fragment,
  ) async {
    try {
      await action();
      fail('esperado erro contendo "$fragment"');
    } catch (e) {
      expect(e.toString(), contains(fragment));
    }
  }

  test(
    'P4: chat/eventos/analytics do grupo, Q&A, salvos e avaliacoes',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? groupId;
      String? questionId;
      String? materialId;

      await signInB(client);
      final userB = client.auth.currentUser!.id;
      await signInA(client);
      final userA = client.auth.currentUser!.id;
      await deleteConnectionBetween(client, userA, userB);

      try {
        final group = await client.rpc(
          'create_group',
          params: {
            'p_name': 'ztest P4 $ts',
            'p_description': 'grupo de teste P4',
            'p_category': 'outros',
            'p_campus': 'Viçosa',
            'p_visibility': 'private',
          },
        );
        groupId = (group as Map)['id'] as String;

        final chatId = await client.rpc(
          'get_or_create_group_chat',
          params: {'p_group_id': groupId},
        ) as String;
        await client.from('messages').insert({
          'conversation_id': chatId,
          'sender_id': userA,
          'content': 'chat do grupo P4 $ts',
          'kind': 'text',
        });

        await inviteUserToGroup(
          client,
          groupId: groupId,
          inviterId: userA,
          targetUserId: userB,
          signInInviter: () => signInA(client),
          signInTarget: () => signInB(client),
        );

        await signInB(client);
        final bChatId = await client.rpc(
          'get_or_create_group_chat',
          params: {'p_group_id': groupId},
        ) as String;
        expect(bChatId, chatId);
        final bMessages = await client
            .from('messages')
            .select('content')
            .eq('conversation_id', chatId);
        expect((bMessages as List).length, greaterThanOrEqualTo(1));

        final summaries = await ChatRepository(client).fetchConversations();
        final groupSummary = summaries.firstWhere((item) => item.id == chatId);
        expect(groupSummary.isGroup, isTrue);
        expect(groupSummary.displayName, 'ztest P4 $ts');

        await signInA(client);
        final start = DateTime.now().add(const Duration(days: 2));
        await client.rpc(
          'create_group_event',
          params: {
            'p_group_id': groupId,
            'p_title': 'Evento P4 $ts',
            'p_description': 'teste',
            'p_starts_at': start.toUtc().toIso8601String(),
            'p_ends_at': start
                .add(const Duration(hours: 2))
                .toUtc()
                .toIso8601String(),
            'p_location': 'UFV',
          },
        );

        await signInB(client);
        final events = await client
            .from('group_events')
            .select('id, title')
            .eq('group_id', groupId);
        expect((events as List).length, 1);
        await expectError(
          () => client.rpc(
            'create_group_event',
            params: {
              'p_group_id': groupId,
              'p_title': 'Evento proibido P4 $ts',
              'p_description': 'teste',
              'p_starts_at': start.toUtc().toIso8601String(),
              'p_ends_at': start
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'p_location': 'UFV',
            },
          ),
          'forbidden',
        );

        final analytics = await client.rpc(
          'group_analytics',
          params: {'p_group_id': groupId},
        ) as Map;
        expect((analytics['members'] as num).toInt(), greaterThanOrEqualTo(2));
        expect(
          (analytics['posts_30d'] as num).toInt(),
          greaterThanOrEqualTo(0),
        );

        final discipline = await client
            .from('disciplines')
            .select('id')
            .limit(1)
            .single();
        await signInA(client);
        final question = await client
            .from('study_questions')
            .insert({
              'id': uuidV4(),
              'discipline_id': discipline['id'],
              'author_id': userA,
              'title': 'Duvida P4 $ts',
              'content': 'Como resolver esta duvida de teste P4 $ts?',
              'status': 'open',
            })
            .select('id')
            .single();
        questionId = question['id'] as String;

        await signInB(client);
        final answer = await client
            .from('study_answers')
            .insert({
              'id': uuidV4(),
              'question_id': questionId,
              'author_id': userB,
              'content': 'Resposta de teste P4 $ts',
              'accepted': false,
            })
            .select('id')
            .single();
        await client.rpc(
          'toggle_study_answer_vote',
          params: {'p_answer_id': answer['id']},
        );

        await signInA(client);
        await client.rpc(
          'accept_study_answer',
          params: {'p_answer_id': answer['id']},
        );
        final accepted = await client
            .from('study_answers')
            .select('accepted')
            .eq('id', answer['id'])
            .single();
        expect(accepted['accepted'], isTrue);
        final resolved = await client
            .from('study_questions')
            .select('status')
            .eq('id', questionId)
            .single();
        expect(resolved['status'], 'resolved');

        await signInAdmin(client);
        await client.rpc('admin_grant_uploader', params: {'p_email': emailA});
        await signInA(client);
        materialId = uuidV4();
        await client.from('study_materials').insert({
          'id': materialId,
          'discipline_id': discipline['id'],
          'author_id': userA,
          'title': 'Material P4 $ts',
          'description': 'teste',
          'kind': 'link',
          'external_url': 'https://example.com/p4-$ts',
          'status': 'pending',
          'consent_version': 'test',
        });
        await signInAdmin(client);
        await client.rpc(
          'admin_review_material',
          params: {
            'p_material_id': materialId,
            'p_approve': true,
            'p_note': 'teste',
          },
        );

        await signInA(client);
        await client.from('study_material_saves').insert({
          'user_id': userA,
          'material_id': materialId,
        });
        final saved = await client
            .from('study_material_saves')
            .select('material_id')
            .eq('user_id', userA);
        expect((saved as List).length, 1);
        await client.rpc(
          'rate_study_material',
          params: {'p_material_id': materialId, 'p_rating': 5},
        );

        await signInB(client);
        await client.rpc(
          'rate_study_material',
          params: {'p_material_id': materialId, 'p_rating': 4},
        );
        final rating = await client.rpc(
          'study_material_rating',
          params: {'p_material_id': materialId},
        ) as Map;
        expect((rating['count'] as num).toInt(), 2);
        expect((rating['average'] as num).toDouble(), 4.5);

        await signInA(client);
        await client.rpc(
          'remove_study_material_rating',
          params: {'p_material_id': materialId},
        );
        await client
            .from('study_material_saves')
            .delete()
            .eq('user_id', userA)
            .eq('material_id', materialId);
      } finally {
        await signInA(client);
        if (questionId != null) {
          try {
            await client.rpc(
              'delete_study_question',
              params: {'p_question_id': questionId},
            );
          } catch (_) {}
        }
        if (materialId != null) {
          await signInAdmin(client);
          try {
            await client.rpc(
              'admin_moderate_content',
              params: {
                'p_target_type': 'material',
                'p_target_id': materialId,
                'p_action': 'delete',
              },
            );
          } catch (_) {}
        }
        await signInA(client);
        if (groupId != null) {
          try {
            await client.rpc('delete_group', params: {'p_group_id': groupId});
          } catch (_) {}
        }
        try {
          await deleteConnectionBetween(client, userA, userB);
        } catch (_) {}
        await client.auth.signOut();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 300)),
  );
}
