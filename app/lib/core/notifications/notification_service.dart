import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // A mensagem de notificacao e exibida pelo sistema. O app busca a central
  // quando abrir, entao nao dependemos de executar codigo em background.
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _currentToken;
  String? _pendingRoute;
  void Function(String route)? _openRoute;

  bool _initialized = false;

  void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
  }

  void setRouteOpener(void Function(String route) opener) {
    _openRoute = opener;
    final pending = _pendingRoute;
    _pendingRoute = null;
    if (pending != null && pending.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => opener(pending));
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _open(route);
      },
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'conexa_default',
        'Conexa',
        description: 'Pedidos, mensagens, conexoes e estudos.',
        importance: Importance.high,
        playSound: true,
      ),
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onMessageOpened(initial);
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session != null) {
        unawaited(_registerToken());
      } else {
        unawaited(_clearLocalState());
      }
    });

    // ignore: deprecated_member_use
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      unawaited(_saveToken(token));
    });

    if (Supabase.instance.client.auth.currentSession != null) {
      await _registerToken();
    }
  }

  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) {
      await _registerToken();
    }
    return granted;
  }

  Future<bool> hasPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> unregisterCurrentToken() async {
    final token = _currentToken ?? await _safeGetToken();
    if (token == null) return;
    try {
      await Supabase.instance.client.rpc(
        'unregister_device_token',
        params: {'p_token': token},
      );
    } catch (error) {
      debugPrint('notification unregister failed: $error');
    }
    _currentToken = null;
    await _local.cancelAll();
  }

  Future<void> _registerToken() async {
    final token = await _safeGetToken();
    if (token == null) return;
    _currentToken = token;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    _currentToken = token;
    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      await Supabase.instance.client.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': 'android'},
      );
    } catch (error) {
      debugPrint('notification token registration failed: $error');
    }
  }

  Future<String?> _safeGetToken() async {
    try {
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('notification token unavailable: $error');
      return null;
    }
  }

  Future<void> _clearLocalState() async {
    _currentToken = null;
    await _local.cancelAll();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'Conexa';
    final body = notification.body ?? 'Voce tem uma nova notificacao.';
    final route = message.data['route'];

    unawaited(
      _local.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'conexa_default',
            'Conexa',
            channelDescription: 'Pedidos, mensagens, conexoes e estudos.',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
        ),
        payload: route,
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && route.isNotEmpty) _open(route);
  }

  void _open(String route) {
    final opener = _openRoute;
    if (opener == null) {
      _pendingRoute = route;
      return;
    }
    opener(route);
  }
}
