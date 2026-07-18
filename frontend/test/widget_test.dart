import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindtrace/main.dart';

void main() {
  testWidgets('Signup screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MindTraceApp());

    // App loads the signup screen by default
    expect(find.text('Sign Up'), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
