import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/screens/dashboard_screen.dart';

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
      // FutureBuilder checks for a saved token at startup.
      // If token exists → go straight to dashboard.
      // If not → show auth screen.
      home: FutureBuilder<bool>(
        future: AuthService().isLoggedIn(),
        builder: (context, snapshot) {
          // While checking storage — show a blank white screen
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2D4B37),
                ),
              ),
            );
          }
          return snapshot.data == true
              ? const DashboardScreen()
              : const AuthScreen(initialIndex: 0);
        },
      ),
    );
  }
}
