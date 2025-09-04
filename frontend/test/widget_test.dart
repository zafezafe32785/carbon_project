import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that splash screen shows the eco icon
    expect(find.byIcon(Icons.eco), findsOneWidget);
    expect(find.text('Carbon Accounting'), findsOneWidget);
  });
}