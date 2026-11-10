import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/firebase_update_service.dart';

class ConexaApp extends StatefulWidget {
  const ConexaApp({super.key});

  @override
  State<ConexaApp> createState() => _ConexaAppState();
}

class _ConexaAppState extends State<ConexaApp> {
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setRouteOpener((route) {
      appRouter.go(route);
    });
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        appRouter.go('/reset-password');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseUpdateService().check();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Conexa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
