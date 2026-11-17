import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/media/media_providers.dart';
import '../data/study_models.dart';
import '../data/study_repository.dart';

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) =>
      StudyRepository(Supabase.instance.client, ref.read(mediaServiceProvider)),
);

final disciplinesProvider = FutureProvider.autoDispose<List<Discipline>>(
  (ref) => ref.read(studyRepositoryProvider).fetchDisciplines(),
);

final materialsProvider = FutureProvider.autoDispose
    .family<List<StudyMaterial>, String>(
      (ref, disciplineId) =>
          ref.read(studyRepositoryProvider).fetchMaterials(disciplineId),
    );

final materialProvider = FutureProvider.autoDispose
    .family<StudyMaterial?, String>(
      (ref, materialId) =>
          ref.read(studyRepositoryProvider).fetchMaterial(materialId),
    );

final canUploadProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(studyRepositoryProvider).canUpload(),
);

final pendingMaterialsProvider =
    FutureProvider.autoDispose<List<StudyMaterial>>(
      (ref) => ref.read(studyRepositoryProvider).fetchPending(),
    );

final studyFileUrlProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, materialId) => ref.read(studyRepositoryProvider).fileUrl(materialId),
);

final questionsProvider = FutureProvider.autoDispose
    .family<List<StudyQuestion>, String>(
      (ref, disciplineId) =>
          ref.read(studyRepositoryProvider).fetchQuestions(disciplineId),
    );

final questionProvider = FutureProvider.autoDispose
    .family<StudyQuestion?, String>(
      (ref, questionId) =>
          ref.read(studyRepositoryProvider).fetchQuestion(questionId),
    );

final answersProvider = FutureProvider.autoDispose
    .family<List<StudyAnswer>, String>(
      (ref, questionId) =>
          ref.read(studyRepositoryProvider).fetchAnswers(questionId),
    );

final savedMaterialsProvider = FutureProvider.autoDispose<List<StudyMaterial>>(
  (ref) => ref.read(studyRepositoryProvider).fetchSavedMaterials(),
);

final materialSavedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, materialId) =>
      ref.read(studyRepositoryProvider).isMaterialSaved(materialId),
);

final materialRatingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, materialId) =>
          ref.read(studyRepositoryProvider).fetchMaterialRating(materialId),
    );

final materialReviewsProvider = FutureProvider.autoDispose
    .family<List<StudyReview>, String>(
      (ref, materialId) =>
          ref.read(studyRepositoryProvider).fetchMaterialReviews(materialId),
    );

final questionAttachmentsProvider = FutureProvider.autoDispose
    .family<List<QaAttachment>, String>(
      (ref, questionId) => ref
          .read(studyRepositoryProvider)
          .fetchQuestionAttachments(questionId),
    );

final answerAttachmentsProvider = FutureProvider.autoDispose
    .family<Map<String, List<QaAttachment>>, String>(
      (ref, questionId) =>
          ref.read(studyRepositoryProvider).fetchAnswerAttachments(questionId),
    );
