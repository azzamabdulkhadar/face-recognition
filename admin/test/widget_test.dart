// Basic smoke test for the admin app.

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/main.dart';

void main() {
  testWidgets('Admin app renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.text('Admin Panel'), findsOneWidget);
  });
}
