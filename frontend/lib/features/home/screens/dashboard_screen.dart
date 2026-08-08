import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../auth/screens/auth_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../chat/screens/intake_chat_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MindTrace',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: MindColors.primary,
                        ),
                      ),
                      Text(
                        'Clinical Mental Health Systems',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: MindColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined,
                        color: MindColors.onSurfaceVariant),
                    onPressed: () async {
                      await AuthService().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const AuthScreen()),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: MindColors.outlineVariant),

            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: MindColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.psychology_outlined,
                          size: 40,
                          color: MindColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome to MindTrace',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MindColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your assessment is ready. Tap below to begin the intake process.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: MindColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Start assessment button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const IntakeChatScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MindColors.primaryContainer,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Start Assessment',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
