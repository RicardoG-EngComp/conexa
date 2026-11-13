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
