import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_models.dart';

class ReportRepository {
  ReportRepository(this._client);

  final SupabaseClient _client;

  Future<void> submit({
    required String reportedUserId,
    required String targetType,
    required String category,
    String? targetId,
    String? description,
    String? contentSnapshot,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('sem sessao');
    await _client.from('reports').insert({
      'reporter_id': user.id,
      'reported_user_id': reportedUserId,
      'target_type': targetType,
      'target_id': targetId,
      'category': category,
      'description': description,
      'content_snapshot': contentSnapshot,
    });
  }

  Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('admins')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<List<Report>> fetchOpenReports() async {
    final rows = await _client
        .from('reports')
        .select()
        .inFilter('status', ['open', 'reviewing'])
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => Report.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> review({
    required String reportId,
    required String reportedUserId,
    required String action,
    String? targetType,
    String? targetId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (action == 'hide' || action == 'restore' || action == 'delete') {
      final type = targetType ?? 'profile';
      final id = targetId ??
          (type == 'profile' ? reportedUserId : null);
      if (id == null) throw Exception('conteudo sem id');
      await _client.rpc(
        'admin_moderate_content',
        params: {
          'p_target_type': type,
          'p_target_id': id,
          'p_action': action,
        },
      );
    }

    final status = (action == 'dismiss' || action == 'restore')
        ? 'dismissed'
        : 'resolved';
    await _client
        .from('reports')
        .update({
          'status': status,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewer_id': user.id,
          'action_taken': action,
        })
        .eq('id', reportId);

    if (action == 'suspend' || action == 'ban') {
      await _client
          .from('profiles')
          .update({'account_status': action == 'ban' ? 'banned' : 'suspended'})
          .eq('id', reportedUserId);
    }

    await _client.from('audit_log').insert({
      'actor_id': user.id,
      'action': action,
      'target_user_id': reportedUserId,
      'metadata': {'report_id': reportId},
    });
  }
}
