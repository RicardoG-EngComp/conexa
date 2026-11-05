import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'study_models.dart';

class StudyRepository {
  StudyRepository(this._client);

  final SupabaseClient _client;

  static const String uploadConsentVersion = '2026-11-upload';

  Future<List<Discipline>> fetchDisciplines() async {
    final rows = await _client
        .from('disciplines')
        .select('id, code, name, course, campus')
        .order('name');
    return (rows as List)
        .map((r) => Discipline.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<StudyMaterial>> fetchMaterials(String disciplineId) async {
    final rows = await _client
        .from('study_materials')
        .select(
          'id, discipline_id, author_id, title, description, kind, '
          'storage_path, external_url, status, created_at',
        )
        .eq('discipline_id', disciplineId)
        .order('created_at', ascending: false);
    final materials = (rows as List)
        .map((r) => StudyMaterial.fromMap(r as Map<String, dynamic>))
        .toList();
    return _attachMeta(materials);
  }

  Future<List<StudyMaterial>> fetchPending() async {
    final rows = await _client
        .from('study_materials')
        .select(
          'id, discipline_id, author_id, title, description, kind, '
          'storage_path, external_url, status, created_at',
        )
        .eq('status', 'pending')
        .order('created_at');
    final materials = (rows as List)
        .map((r) => StudyMaterial.fromMap(r as Map<String, dynamic>))
        .toList();
    return _attachMeta(materials);
  }

  Future<StudyMaterial?> fetchMaterial(String id) async {
    final row = await _client
        .from('study_materials')
        .select(
          'id, discipline_id, author_id, title, description, kind, '
          'storage_path, external_url, status, created_at',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final material = StudyMaterial.fromMap(row);
    final enriched = await _attachMeta([material]);
    return enriched.isEmpty ? null : enriched.first;
  }

  Future<List<StudyMaterial>> _attachMeta(
    List<StudyMaterial> materials,
  ) async {
    if (materials.isEmpty) return materials;

    final ids = materials.map((m) => m.id).toList();
    final authorIds = materials.map((m) => m.authorId).toSet().toList();
    final myId = _client.auth.currentUser?.id;

    final votes = await _client
        .from('study_material_votes')
        .select('material_id, user_id')
        .inFilter('material_id', ids);

    final counts = <String, int>{};
    final mine = <String>{};
    for (final row in (votes as List)) {
      final materialId = row['material_id'] as String;
      counts[materialId] = (counts[materialId] ?? 0) + 1;
      if (myId != null && row['user_id'] == myId) {
        mine.add(materialId);
      }
    }

    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', authorIds);
    final names = <String, String>{
      for (final row in (profiles as List))
        row['id'] as String: (row['display_name'] as String?) ?? 'Aluno',
    };

    return materials
        .map(
          (m) => m.copyWith(
            authorName: names[m.authorId] ?? 'Aluno',
            upvotes: counts[m.id] ?? 0,
            votedByMe: mine.contains(m.id),
          ),
        )
        .toList();
  }

  Future<bool> canUpload() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('study_uploaders')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<String> uploadFile({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final name = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final path = '${user.id}/$name';
    await _client.storage.from('study-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );
    return path;
  }

  Future<void> createLinkMaterial({
    required String disciplineId,
    required String title,
    String? description,
    required String url,
  }) async {
    await _createMaterial(
      disciplineId: disciplineId,
      title: title,
      description: description,
      kind: 'link',
      externalUrl: url,
    );
  }

  Future<void> createFileMaterial({
    required String disciplineId,
    required String title,
    String? description,
    required String storagePath,
    required String kind,
  }) async {
    await _createMaterial(
      disciplineId: disciplineId,
      title: title,
      description: description,
      kind: kind,
      storagePath: storagePath,
    );
  }

  Future<void> _createMaterial({
    required String disciplineId,
    required String title,
    String? description,
    required String kind,
    String? storagePath,
    String? externalUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');

    await _client.from('upload_consents').insert({
      'user_id': user.id,
      'version': uploadConsentVersion,
    });

    await _client.from('study_materials').insert({
      'discipline_id': disciplineId,
      'author_id': user.id,
      'title': title.trim(),
      'description': description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
      'kind': kind,
      'storage_path': storagePath,
      'external_url': externalUrl,
      'status': 'pending',
      'consent_version': uploadConsentVersion,
    });
  }

  Future<void> toggleVote({
    required String materialId,
    required bool voted,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (voted) {
      await _client
          .from('study_material_votes')
          .delete()
          .eq('material_id', materialId)
          .eq('user_id', user.id);
    } else {
      await _client.from('study_material_votes').insert({
        'material_id': materialId,
        'user_id': user.id,
      });
    }
  }

  Future<String?> fileUrl(String materialId) async {
    final response = await _client.functions.invoke(
      'study-file-url',
      body: {'material_id': materialId},
    );
    final data = response.data;
    if (data is Map && data['url'] is String) {
      return data['url'] as String;
    }
    return null;
  }

  Future<void> reviewMaterial({
    required String materialId,
    required bool approve,
    String? note,
  }) async {
    await _client.rpc(
      'admin_review_material',
      params: {
        'p_material_id': materialId,
        'p_approve': approve,
        'p_note': note,
      },
    );
  }

  Future<void> deleteMaterial(String materialId) async {
    await _client.rpc(
      'admin_moderate_content',
      params: {
        'p_target_type': 'material',
        'p_target_id': materialId,
        'p_action': 'delete',
      },
    );
  }

  Future<void> grantUploader(String email) async {
    await _client.rpc(
      'admin_grant_uploader',
      params: {'p_email': email.trim()},
    );
  }
}
