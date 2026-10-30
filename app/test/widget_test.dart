import 'package:flutter_test/flutter_test.dart';
import 'package:match/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  testWidgets('abre na tela de boas-vindas', (tester) async {
    await tester.pumpWidget(const MatchApp());
    await tester.pumpAndSettle();

    expect(find.text('Tenho 18 anos ou mais'), findsOneWidget);
  });
}
