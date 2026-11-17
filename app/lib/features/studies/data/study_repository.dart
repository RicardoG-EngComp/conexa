import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/media/image_processor.dart';
import '../../../core/media/media_service.dart';
import '../../../core/utils/uuid.dart';
import 'study_models.dart';

class StudyRepository {
  StudyRepository(this._client, this._media);

  final SupabaseClient _client;
  final MediaService _media;

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

  Future<List<StudyMaterial>> _attachMeta(List<StudyMaterial> materials) async {
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
    required String contentType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');

    final assetId = uuidV4();

    if (contentType == 'application/pdf') {
      final full = await _media.uploadImage(
        bytes: bytes,
        kind: 'study_pdf',
        variant: 'full',
        contentType: 'application/pdf',
        assetId: assetId,
      );
      return full.key;
    }

    final processed = await ImageProcessor.studyImage(bytes);
    final full = await _media.uploadImage(
      bytes: processed.full,
      kind: 'study_image',
      variant: 'full',
      contentType: 'image/webp',
      assetId: assetId,
      width: processed.width,
      height: processed.height,
    );

    try {
      await _media.uploadImage(
        bytes: processed.thumb,
        kind: 'study_image',
        variant: 'thumb',
        contentType: 'image/webp',
        assetId: assetId,
        width: processed.thumbWidth,
        height: processed.thumbHeight,
      );
    } catch (_) {
      // A imagem cheia continua utilizavel.
    }

    return full.key;
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

  Future<List<StudyQuestion>> fetchQuestions(String disciplineId) async {
    final rows = await _client
        .from('study_questions')
        .select(
          'id, discipline_id, author_id, title, content, status, created_at',
        )
        .eq('discipline_id', disciplineId)
        .order('created_at', ascending: false);
    final questions = (rows as List).cast<Map<String, dynamic>>();
    if (questions.isEmpty) return [];

    final ids = questions.map((q) => q['id'] as String).toList();
    final authorIds = questions
        .map((q) => q['author_id'] as String)
        .toSet()
        .toList();
    final answerRows = await _client
        .from('study_answers')
        .select('question_id')
        .inFilter('question_id', ids);
    final answerCounts = <String, int>{};
    for (final row in (answerRows as List)) {
      final id = row['question_id'] as String;
      answerCounts[id] = (answerCounts[id] ?? 0) + 1;
    }
    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', authorIds);
    final names = <String, String>{
      for (final row in (profiles as List))
        row['id'] as String: (row['display_name'] as String?) ?? 'Aluno',
    };

    return questions
        .map(
          (q) => StudyQuestion(
            id: q['id'] as String,
            disciplineId: q['discipline_id'] as String,
            authorId: q['author_id'] as String,
            title: (q['title'] as String?) ?? '',
            content: (q['content'] as String?) ?? '',
            status: (q['status'] as String?) ?? 'open',
            createdAt: DateTime.parse(q['created_at'] as String),
            authorName: names[q['author_id'] as String] ?? 'Aluno',
            answerCount: answerCounts[q['id'] as String] ?? 0,
          ),
        )
        .toList();
  }

  Future<StudyQuestion?> fetchQuestion(String id) async {
    final row = await _client
        .from('study_questions')
        .select(
          'id, discipline_id, author_id, title, content, status, created_at',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final profile = await _client
        .from('profiles_public')
        .select('display_name')
        .eq('id', row['author_id'])
        .maybeSingle();
    return StudyQuestion(
      id: row['id'] as String,
      disciplineId: row['discipline_id'] as String,
      authorId: row['author_id'] as String,
      title: (row['title'] as String?) ?? '',
      content: (row['content'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'open',
      createdAt: DateTime.parse(row['created_at'] as String),
      authorName: (profile?['display_name'] as String?) ?? 'Aluno',
    );
  }

  Future<String> createQuestion({
    required String disciplineId,
    required String title,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final id = uuidV4();
    await _client.from('study_questions').insert({
      'id': id,
      'discipline_id': disciplineId,
      'author_id': user.id,
      'title': title.trim(),
      'content': content.trim(),
      'status': 'open',
    });
    return id;
  }

  Future<QaAttachmentDraft> uploadQaAttachment({
    required Uint8List bytes,
    required bool image,
    String? name,
  }) async {
    if (image) {
      final processed = await ImageProcessor.studyImage(bytes);
      final uploaded = await _media.uploadImage(
        bytes: processed.full,
        kind: 'qa_image',
        variant: 'full',
        contentType: 'image/webp',
        width: processed.width,
        height: processed.height,
      );
      return QaAttachmentDraft(
        path: uploaded.key,
        kind: 'image',
        mimeType: 'image/webp',
        byteSize: uploaded.bytes,
        name: name,
      );
    }

    final uploaded = await _media.uploadImage(
      bytes: bytes,
      kind: 'qa_file',
      variant: 'full',
      contentType: 'application/pdf',
    );
    return QaAttachmentDraft(
      path: uploaded.key,
      kind: 'file',
      mimeType: 'application/pdf',
      byteSize: uploaded.bytes,
      name: name,
    );
  }

  Future<void> addQuestionAttachment(
    String questionId,
    QaAttachmentDraft draft,
  ) async {
    await _client.from('study_question_attachments').insert({
      'question_id': questionId,
      'owner_id': _client.auth.currentUser?.id,
      'object_key': draft.path,
      'kind': draft.kind,
      'mime_type': draft.mimeType,
      'byte_size': draft.byteSize,
      'name': draft.name,
    });
  }

  Future<void> addAnswerAttachment(
    String answerId,
    QaAttachmentDraft draft,
  ) async {
    await _client.from('study_answer_attachments').insert({
      'answer_id': answerId,
      'owner_id': _client.auth.currentUser?.id,
      'object_key': draft.path,
      'kind': draft.kind,
      'mime_type': draft.mimeType,
      'byte_size': draft.byteSize,
      'name': draft.name,
    });
  }

  Future<List<QaAttachment>> fetchQuestionAttachments(String questionId) async {
    final rows = await _client
        .from('study_question_attachments')
        .select('id, object_key, kind, mime_type, name')
        .eq('question_id', questionId);
    return (rows as List)
        .map(
          (r) => QaAttachment(
            id: r['id'] as String,
            path: r['object_key'] as String,
            kind: r['kind'] as String,
            mimeType: r['mime_type'] as String,
            name: r['name'] as String?,
          ),
        )
        .toList();
  }

  Future<Map<String, List<QaAttachment>>> fetchAnswerAttachments(
    String questionId,
  ) async {
    final answerRows = await _client
        .from('study_answers')
        .select('id')
        .eq('question_id', questionId);
    final ids = (answerRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('study_answer_attachments')
        .select('id, answer_id, object_key, kind, mime_type, name')
        .inFilter('answer_id', ids);
    final result = <String, List<QaAttachment>>{};
    for (final r in (rows as List)) {
      result
          .putIfAbsent(r['answer_id'] as String, () => [])
          .add(
            QaAttachment(
              id: r['id'] as String,
              path: r['object_key'] as String,
              kind: r['kind'] as String,
              mimeType: r['mime_type'] as String,
              name: r['name'] as String?,
            ),
          );
    }
    return result;
  }

  Future<String> createAnswer(String questionId, String content) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    final id = uuidV4();
    await _client.from('study_answers').insert({
      'id': id,
      'question_id': questionId,
      'author_id': user.id,
      'content': content.trim(),
      'accepted': false,
    });
    return id;
  }

  Future<List<StudyAnswer>> fetchAnswers(String questionId) async {
    final rows = await _client
        .from('study_answers')
        .select('id, question_id, author_id, content, accepted, created_at')
        .eq('question_id', questionId)
        .order('accepted', ascending: false)
        .order('created_at');
    final answers = (rows as List).cast<Map<String, dynamic>>();
    if (answers.isEmpty) return [];

    final authorIds = answers
        .map((a) => a['author_id'] as String)
        .toSet()
        .toList();
    final profiles = await _client
        .from('profiles_public')
        .select('id, display_name')
        .inFilter('id', authorIds);
    final names = <String, String>{
      for (final row in (profiles as List))
        row['id'] as String: (row['display_name'] as String?) ?? 'Aluno',
    };
    final results = await _client.rpc(
      'study_answer_results',
      params: {'p_question_id': questionId},
    ) as List;
    final votes = <String, int>{};
    final mine = <String>{};
    for (final row in results) {
      final id = row['answer_id'] as String;
      votes[id] = (row['votes'] as num).toInt();
      if (row['my_vote'] == true) mine.add(id);
    }

    return answers
        .map(
          (a) => StudyAnswer(
            id: a['id'] as String,
            questionId: a['question_id'] as String,
            authorId: a['author_id'] as String,
            content: (a['content'] as String?) ?? '',
            accepted: a['accepted'] == true,
            createdAt: DateTime.parse(a['created_at'] as String),
            authorName: names[a['author_id'] as String] ?? 'Aluno',
            votes: votes[a['id'] as String] ?? 0,
            votedByMe: mine.contains(a['id']),
          ),
        )
        .toList();
  }

  Future<void> acceptAnswer(String answerId) async {
    await _client.rpc('accept_study_answer', params: {'p_answer_id': answerId});
  }

  Future<void> toggleAnswerVote(String answerId) async {
    await _client.rpc(
      'toggle_study_answer_vote',
      params: {'p_answer_id': answerId},
    );
  }

  Future<void> deleteAnswer(String answerId) async {
    await _client.rpc('delete_study_answer', params: {'p_answer_id': answerId});
  }

  Future<bool> isMaterialSaved(String materialId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('study_material_saves')
        .select('material_id')
        .eq('user_id', user.id)
        .eq('material_id', materialId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleMaterialSave(String materialId, bool saved) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (saved) {
      await _client
          .from('study_material_saves')
          .delete()
          .eq('user_id', user.id)
          .eq('material_id', materialId);
    } else {
      await _client.from('study_material_saves').insert({
        'user_id': user.id,
        'material_id': materialId,
      });
    }
  }

  Future<List<StudyMaterial>> fetchSavedMaterials() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('study_material_saves')
        .select('material_id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final ids = (rows as List).map((r) => r['material_id'] as String).toList();
    if (ids.isEmpty) return [];
    final materialRows = await _client
        .from('study_materials')
        .select(
          'id, discipline_id, author_id, title, description, kind, '
          'storage_path, external_url, status, created_at',
        )
        .inFilter('id', ids);
    final materials = (materialRows as List)
        .map((r) => StudyMaterial.fromMap(r as Map<String, dynamic>))
        .toList();
    final enriched = await _attachMeta(materials);
    final byId = {for (final m in enriched) m.id: m};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> rateMaterial(
    String materialId,
    int rating, {
    String? comment,
  }) async {
    await _client.rpc(
      'rate_study_material',
      params: {
        'p_material_id': materialId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );
  }

  Future<List<StudyReview>> fetchMaterialReviews(String materialId) async {
    final rows = await _client.rpc(
      'study_material_reviews',
      params: {'p_material_id': materialId},
    ) as List;
    return rows
        .map(
          (row) => StudyReview(
            userId: row['user_id'] as String,
            displayName: (row['display_name'] as String?) ?? 'Aluno',
            rating: (row['rating'] as num).toInt(),
            comment: (row['comment'] as String?) ?? '',
            updatedAt: DateTime.parse(row['updated_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<StudyQuestion>> searchQuestions(
    String disciplineId,
    String query,
  ) async {
    final rows = await _client.rpc(
      'search_study_qa',
      params: {
        'p_discipline_id': disciplineId,
        'p_query': query,
        'p_limit': 40,
        'p_offset': 0,
      },
    ) as List;
    final ids = rows.map((r) => r['question_id'] as String).toSet();
    if (ids.isEmpty) return [];
    final all = await fetchQuestions(disciplineId);
    return all.where((q) => ids.contains(q.id)).toList();
  }

  Future<Map<String, dynamic>> fetchMaterialRating(String materialId) async {
    final result = await _client.rpc(
      'study_material_rating',
      params: {'p_material_id': materialId},
    );
    return (result as Map).cast<String, dynamic>();
  }

  Future<void> removeMaterialRating(String materialId) async {
    await _client.rpc(
      'remove_study_material_rating',
      params: {'p_material_id': materialId},
    );
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.rpc(
      'delete_study_question',
      params: {'p_question_id': questionId},
    );
  }
}
