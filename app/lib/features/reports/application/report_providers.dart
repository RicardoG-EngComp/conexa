import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/report_models.dart';
import '../data/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(Supabase.instance.client),
);

final isAdminProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(reportRepositoryProvider).isAdmin(),
);

final openReportsProvider = FutureProvider.autoDispose<List<Report>>(
  (ref) => ref.read(reportRepositoryProvider).fetchOpenReports(),
);
