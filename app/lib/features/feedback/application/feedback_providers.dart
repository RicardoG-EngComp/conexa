import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/feedback_models.dart';
import '../data/feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(Supabase.instance.client),
);

final myFeedbackProvider = FutureProvider.autoDispose<List<FeedbackEntry>>(
  (ref) => ref.read(feedbackRepositoryProvider).fetchMine(),
);

typedef AdminFeedbackQuery = ({FeedbackKind kind, int group});

final adminFeedbackProvider = FutureProvider.autoDispose
    .family<List<FeedbackEntry>, AdminFeedbackQuery>((ref, query) async {
      final statuses = switch (query.kind) {
        FeedbackKind.bug => switch (query.group) {
          1 => <String>['in_progress'],
          2 => <String>['fixed', 'wontfix'],
          _ => <String>['new', 'triaged'],
        },
        FeedbackKind.suggestion => switch (query.group) {
          1 => <String>['accepted'],
          2 => <String>['implemented', 'declined'],
          _ => <String>['new', 'analyzed'],
        },
      };
      return ref
          .read(feedbackRepositoryProvider)
          .fetchForAdmin(kind: query.kind, statuses: statuses);
    });

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (_) {
    return '';
  }
});
