import 'package:flutter_test/flutter_test.dart';
import 'package:golf_rounder/main.dart';

void main() {
  testWidgets('ROUNDER app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RounderApp());
    expect(find.text('ROUNDER'), findsOneWidget);
  });
}
