import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ic_sesim/main.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('İlk kullanım ekranı açılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IcSesimApp());
    await tester.pumpAndSettle();
    expect(find.text('Kendine ait bir alan'), findsOneWidget);
    expect(find.text('Devam et'), findsOneWidget);
  });
}
