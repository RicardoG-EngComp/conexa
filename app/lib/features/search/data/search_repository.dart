import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'search_models.dart';

final studySearchRepositoryProvider = Provider<StudySearchRepository>(
  (ref) => StudySearchRepository(Supabase.instance.client),
);

class StudySearchRepository {
  StudySearchRepository(this._client);

  final SupabaseClient _client;

  Future<StudySearchResults> search(String query) async {
    final result = await _client.rpc(
      'search_study_catalog',
      params: {'p_query': query.trim(), 'p_limit': 20},
    );
    return StudySearchResults.fromMap((result as Map).cast<String, dynamic>());
  }
}
