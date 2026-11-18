import 'package:conexa/core/theme/app_colors.dart';
import 'package:conexa/core/theme/app_skin.dart';
import 'package:conexa/core/theme/app_skin_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppColors.apply(AppSkin.conexa));

  test('selecionar skin aplica e persiste a escolha', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final skin = AppSkin.all.firstWhere((item) => item.id == 'skin_09');
    await container.read(appSkinProvider.notifier).select(skin);

    expect(AppColors.skin.id, 'skin_09');
    expect(container.read(appSkinProvider).id, 'skin_09');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSkinController.prefKey), 'skin_09');
  });
}
