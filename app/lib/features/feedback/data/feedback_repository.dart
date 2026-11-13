import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/uuid.dart';
import 'feedback_models.dart';

class FeedbackRepository {
  FeedbackRepository(this._client);

  final SupabaseClient _client;

  Future<FeedbackEntry> submitBug({
    required String title,
    required String description,
    String? steps,
    String? expected,
    String? actual,
    String? platform,
    String? appVersion,
    Uint8List? screenshotBytes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');

    final id = uuidV4();
    String? screenshotPath;
    if (screenshotBytes != null && screenshotBytes.isNotEmpty) {
      screenshotPath = await _uploadScreenshot(
        userId: user.id,
        feedbackId: id,
        bytes: screenshotBytes,
      );
    }

    try {
      final row = await _client
          .from('bug_reports')
          .insert({
            'id': id,
            'reporter_id': user.id,
            'title': title.trim(),
            'description': description.trim(),
            'steps': _optional(steps),
            'expected': _optional(expected),
            'actual': _optional(actual),
            'platform': _optional(platform),
            'app_version': _optional(appVersion),
            'screenshot_path': screenshotPath,
          })
          .select()
          .single();
      return FeedbackEntry.fromBug(row);
    } catch (error) {
      if (screenshotPath != null) {
        await _removeQuietly(screenshotPath);
      }
      rethrow;
    }
  }

  Future<FeedbackEntry> submitSuggestion({
    required String title,
    required String description,
    String? problem,
    String? proposal,
    String? impact,
    String? platform,
    String? appVersion,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');

    final row = await _client
        .from('suggestions')
        .insert({
          'id': uuidV4(),
          'reporter_id': user.id,
          'title': title.trim(),
          'description': description.trim(),
          'problem': _optional(problem),
          'proposal': _optional(proposal),
          'impact': _optional(impact),
          'platform': _optional(platform),
          'app_version': _optional(appVersion),
        })
        .select()
        .single();
    return FeedbackEntry.fromSuggestion(row);
  }

  Future<List<FeedbackEntry>> fetchMine() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final rows = await Future.wait([
      _client
          .from('bug_reports')
          .select()
          .eq('reporter_id', user.id)
          .order('created_at', ascending: false)
          .limit(50),
      _client
          .from('suggestions')
          .select()
          .eq('reporter_id', user.id)
          .order('created_at', ascending: false)
          .limit(50),
    ]);

    final entries = <FeedbackEntry>[
      ...(rows[0] as List).map(
        (row) => FeedbackEntry.fromBug(row as Map<String, dynamic>),
      ),
      ...(rows[1] as List).map(
        (row) => FeedbackEntry.fromSuggestion(row as Map<String, dynamic>),
      ),
    ];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<List<FeedbackEntry>> fetchForAdmin({
    required FeedbackKind kind,
    List<String>? statuses,
  }) async {
    final base = _client.from(_tableFor(kind)).select();
    final filtered = statuses == null || statuses.isEmpty
        ? base
        : base.inFilter('status', statuses);
    final rows = await filtered
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map(
          (row) => kind == FeedbackKind.bug
              ? FeedbackEntry.fromBug(row as Map<String, dynamic>)
              : FeedbackEntry.fromSuggestion(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> updateStatus(FeedbackEntry entry, String status) async {
    await _client
        .from(_tableFor(entry.kind))
        .update({'status': status})
        .eq('id', entry.id);
  }

  Future<String?> signedScreenshotUrl(String path) async {
    try {
      return await _client.storage
          .from('feedback-media')
          .createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  String _tableFor(FeedbackKind kind) =>
      kind == FeedbackKind.bug ? 'bug_reports' : 'suggestions';

  Future<String> _uploadScreenshot({
    required String userId,
    required String feedbackId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/$feedbackId.jpg';
    await _client.storage
        .from('feedback-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _removeQuietly(String path) async {
    try {
      await _client.storage.from('feedback-media').remove([path]);
    } catch (_) {}
  }

  String? _optional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
