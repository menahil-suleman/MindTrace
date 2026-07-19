import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/auth/screens/signup_screen.dart';

void main() {
  runApp(const MindTraceApp());
}

class MindTraceApp extends StatelessWidget {
  const MindTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindTrace',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SignupScreen(),
    );
  }
}
