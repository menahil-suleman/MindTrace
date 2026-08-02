import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../auth/services/auth_service.dart';
import '../widgets/assessment_header.dart';
import 'chatbot_intake_screen.dart';

/// "Welcome / Start" screen — matches UI reference image 10.
/// Entry point into the Sprint-2 flow: Start → Chatbot Intake → ... → Results.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _authService = AuthService();
  String _greetingName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      setState(() => _greetingName = user.username);
    } catch (_) {
      // Non-fatal — greeting just falls back to a generic "there".
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MindColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              AssessmentHeader(
                stepIndex: 1,
                totalSteps: 5,
                onExit: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            color: MindColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand_rounded,
                            size: 64,
                            color: MindColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _greetingName.isEmpty ? 'Hello.' : 'Hello, $_greetingName.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "I'm here to understand how you've been feeling recently.",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: MindColors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 28),
                      const _InfoRow(
                        icon: Icons.access_time_rounded,
                        text: 'This usually takes about 8–10 minutes.',
                      ),
                      const SizedBox(height: 18),
                      const _InfoRow(
                        icon: Icons.lock_outline_rounded,
                        text: 'Your answers are private and secure.',
                      ),
                      const SizedBox(height: 18),
                      const _InfoRow(
                        icon: Icons.assignment_outlined,
                        text: 'This is not a diagnosis. It\'s here to help you '
                            'understand yourself better.',
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatbotIntakeScreen()),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Start Assessment'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: MindColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
