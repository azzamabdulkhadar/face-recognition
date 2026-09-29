// Basic smoke test for the Face Recognition Demo app.

import 'package:flutter_test/flutter_test.dart';

import 'package:employees/main.dart';

void main() {
  testWidgets('Home screen renders the two main flows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FaceRecognitionApp());
    await tester.pump();

    expect(find.text('Face Recognition Demo'), findsOneWidget);
    expect(find.text('Employees'), findsOneWidget);
    expect(find.text('Recognize'), findsOneWidget);
  });
}
