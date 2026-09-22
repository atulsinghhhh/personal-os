import 'package:flutter_test/flutter_test.dart';

import 'package:app/app.dart';

void main() {
  testWidgets('PersonalOsApp renders the design token gallery', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PersonalOsApp());
    await tester.pumpAndSettle();

    expect(find.text('Design Token Gallery'), findsOneWidget);
  });
}
