import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_skin.dart';
import 'core/theme/app_skin_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  try {
    final prefs = await SharedPreferences.getInstance();
    AppColors.apply(AppSkin.byId(prefs.getString(AppSkinController.prefKey)));
  } catch (_) {
    AppColors.apply(AppSkin.conexa);
  }
  await NotificationService.instance.initialize();
  runApp(const ProviderScope(child: ConexaApp()));
}
