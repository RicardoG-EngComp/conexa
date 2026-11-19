import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campus_models.dart';

final campusRepositoryProvider = Provider<CampusRepository>(
  (ref) => CampusRepository(Supabase.instance.client),
);

final campusEventsProvider = FutureProvider.autoDispose<List<CampusEvent>>((
  ref,
) async {
  return ref.read(campusRepositoryProvider).fetchEvents();
});

final campusPlacesProvider = FutureProvider.autoDispose<List<CampusPlace>>((
  ref,
) async {
  return ref.read(campusRepositoryProvider).fetchPlaces();
});

class CampusRepository {
  CampusRepository(this._client);

  final SupabaseClient _client;

  Future<List<CampusEvent>> fetchEvents() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('campus_events')
        .select(
          'id, title, description, starts_at, ends_at, location, ticket_url, '
          'image_url, organizer, campus, course, tags, status',
        )
        .eq('status', 'approved')
        .or('ends_at.gte.$now,ends_at.is.null')
        .order('starts_at')
        .limit(30);
    return (rows as List)
        .map((row) => CampusEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CampusPlace>> fetchPlaces() async {
    final rows = await _client
        .from('campus_places')
        .select(
          'id, name, description, category, latitude, longitude, image_url, '
          'status, created_by',
        )
        .eq('status', 'approved')
        .order('category')
        .order('name');
    return (rows as List)
        .map((row) => CampusPlace.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> suggestPlace({
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('campus_places').insert({
      'name': name.trim(),
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'description': description?.trim(),
      'status': 'pending',
      'created_by': user.id,
    });
  }
}
