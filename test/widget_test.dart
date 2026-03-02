import 'package:flutter_test/flutter_test.dart';
import 'package:aigo_mobile/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AigoApp());
    expect(find.text('aigo'), findsWidgets);
  });
}
