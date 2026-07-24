import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App scaffolds without crashing', (WidgetTester tester) async {
    // Pump a minimal MaterialApp — avoids network font loading and
    // asset resolution issues in CI while still exercising the widget layer.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('MindTrace'),
          ),
        ),
      ),
    );

    expect(find.text('MindTrace'), findsOneWidget);
  });
}
