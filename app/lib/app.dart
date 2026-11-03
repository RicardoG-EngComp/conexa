import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_info.dart';
import 'core/update/update_screen.dart';
import 'core/update/update_service.dart';

class MatchApp extends StatefulWidget {
  const MatchApp({super.key});

  @override
  State<MatchApp> createState() => _MatchAppState();
}

class _MatchAppState extends State<MatchApp> with WidgetsBindingObserver {
  final _updateService = UpdateService();
  StreamSubscription<AuthState>? _subscription;
  UpdateInfo? _updateInfo;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        appRouter.go('/reset-password');
      }
    });
    _checkUpdate();
  }

  Future<void> _checkUpdate({bool silent = false}) async {
    if (!silent) {
      setState(() => _checking = true);
    }
    final info = await _updateService.check();
    if (!mounted) return;
    setState(() {
      _updateInfo = info;
      _checking = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUpdate(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (_updateInfo != null && _updateInfo!.mandatory) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: UpdateScreen(info: _updateInfo!, service: _updateService),
      );
    }

    return MaterialApp.router(
      title: 'match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
