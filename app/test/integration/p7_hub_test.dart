import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final skip = skipIfNoCredentials();

  final emailA = Platform.environment['TEST_USER_A_EMAIL'] ?? '';
  final passwordA = Platform.environment['TEST_USER_A_PASSWORD'] ?? '';
  final emailAdmin = Platform.environment['TEST_ADMIN_EMAIL'] ?? '';
  final passwordAdmin = Platform.environment['TEST_ADMIN_PASSWORD'] ?? '';

  test(
    'P7: busca academica e conteudo de campus',
    () async {
      final client = createSupabaseClient()!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      String? placeId;
      String? eventId;

      await signInWithRetry(client, emailA, passwordA);

      final result = await client.rpc(
        'search_study_catalog',
        params: {'p_query': 'calculo', 'p_limit': 10},
      );
      expect(result, isA<Map>());
      expect((result as Map).containsKey('materials'), isTrue);
      expect(result.containsKey('disciplines'), isTrue);
      expect(result.containsKey('professors'), isTrue);
      expect(result.containsKey('questions'), isTrue);
      expect((result['disciplines'] as List), isNotEmpty);

      await signInWithRetry(client, emailAdmin, passwordAdmin);
      final adminId = client.auth.currentUser!.id;

      final place = await client
          .from('campus_places')
          .insert({
            'name': 'ztest local $ts',
            'category': 'Ponto turístico',
            'latitude': -20.7645,
            'longitude': -42.8695,
            'status': 'approved',
            'created_by': adminId,
            'approved_by': adminId,
          })
          .select('id')
          .single();
      placeId = place['id'] as String;

      final event = await client
          .from('campus_events')
          .insert({
            'title': 'ztest evento $ts',
            'starts_at': DateTime.now()
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
            'location': 'Campus UFV',
            'status': 'approved',
            'created_by': adminId,
            'approved_by': adminId,
          })
          .select('id')
          .single();
      eventId = event['id'] as String;

      await signInWithRetry(client, emailA, passwordA);
      final visiblePlace = await client
          .from('campus_places')
          .select('name')
          .eq('id', placeId)
          .single();
      expect(visiblePlace['name'], 'ztest local $ts');

      final visibleEvent = await client
          .from('campus_events')
          .select('title')
          .eq('id', eventId)
          .single();
      expect(visibleEvent['title'], 'ztest evento $ts');

      await signInWithRetry(client, emailAdmin, passwordAdmin);
      await client.from('campus_places').delete().eq('id', placeId);
      await client.from('campus_events').delete().eq('id', eventId);
      await client.auth.signOut();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
