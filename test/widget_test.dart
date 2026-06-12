import 'package:flutter_test/flutter_test.dart';
import 'package:kalender_indonesia/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KalenderIndonesiaApp());
    expect(find.byType(KalenderIndonesiaApp), findsOneWidget);
  });
}
