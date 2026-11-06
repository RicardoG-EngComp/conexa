import 'package:firebase_app_distribution/firebase_app_distribution.dart';
import 'package:flutter/foundation.dart';

class FirebaseUpdateService {
  static bool _checkedThisSession = false;

  Future<void> check({bool force = false}) async {
    if (!kReleaseMode) return;
    if (_checkedThisSession && !force) return;
    _checkedThisSession = true;
    try {
      await updateIfNewReleaseAvailable();
    } catch (_) {
      // Sem atualização, sem testador logado ou API desabilitada.
    }
  }
}
