import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/main.dart';

void main() {
  testWidgets('SehatPass app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SehatPassApp());
    expect(find.byType(SehatPassApp), findsOneWidget);
  });
}
