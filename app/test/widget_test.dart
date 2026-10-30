import 'package:flutter_test/flutter_test.dart';
import 'package:match/app.dart';

void main() {
  testWidgets('abre na tela de boas-vindas', (tester) async {
    await tester.pumpWidget(const MatchApp());
    await tester.pumpAndSettle();

    expect(find.text('Tenho 18 anos ou mais'), findsOneWidget);
  });
}
