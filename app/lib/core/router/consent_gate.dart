import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';

class ConsentGate {
  ConsentGate._();

  static String? _checkedUserId;
  static bool _accepted = false;
  static Future<bool>? _pending;
  static String? _pendingUserId;
  static int _generation = 0;

  static Future<bool> hasConsents() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return Future.value(false);
    if (_checkedUserId == user.id) return Future.value(_accepted);
    final pending = _pending;
    if (pending != null && _pendingUserId == user.id) return pending;
    final generation = _generation;
    _pendingUserId = user.id;
    return _pending = _load(user.id, generation);
  }

  static Future<bool> _load(String userId, int generation) async {
    try {
      final accepted =
          await AuthRepository(Supabase.instance.client).hasConsents();
      if (generation == _generation) {
        _checkedUserId = userId;
        _accepted = accepted;
      }
      return accepted;
    } catch (_) {
      return true;
    } finally {
      if (generation == _generation) {
        _pending = null;
        _pendingUserId = null;
      }
    }
  }

  static void markAccepted() {
    _generation++;
    _pending = null;
    _pendingUserId = null;
    _checkedUserId = Supabase.instance.client.auth.currentUser?.id;
    _accepted = true;
  }

  static void invalidate() {
    _generation++;
    _pending = null;
    _pendingUserId = null;
    _checkedUserId = null;
    _accepted = false;
  }
}
