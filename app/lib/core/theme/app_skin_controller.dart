import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'app_skin.dart';

final appSkinProvider = NotifierProvider<AppSkinController, AppSkin>(
  AppSkinController.new,
);

class AppSkinController extends Notifier<AppSkin> {
  static const prefKey = 'app_skin_id';

  @override
  AppSkin build() => AppColors.skin;

  Future<void> select(AppSkin skin) async {
    AppColors.apply(skin);
    state = skin;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, skin.id);
    } catch (_) {
      // A escolha continua valida nesta sessao mesmo sem persistencia.
    }
  }
}
