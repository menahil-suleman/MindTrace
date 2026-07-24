import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class LinkSentScreen extends StatefulWidget {
  final String email;

  const LinkSentScreen({super.key, required this.email});

  @override
  State<LinkSentScreen> createState() => _LinkSentScreenState();
}

class _LinkSentScreenState extends State<LinkSentScreen> {
  final _authService = AuthService();
  bool _isResending = false;
  bool _resentSuccess = false;

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _resentSuccess = false;
    });
    try {
      await _authService.forgotPassword(email: widget.email);
      if (!mounted) return;
      setState(() => _resentSuccess = true);
      // Reset the tick after 2 s
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _resentSuccess = false);
    } catch (_) {
      // Silent — backend always returns the same generic message
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Main content ─────────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: MindColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            size: 40,
                            color: MindColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Heading
                        const Text(
                          'Link Sent',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: MindColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtext
                        const Text(
                          "We've sent a verification link to your email. Please check your inbox to continue.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: MindColors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Enter code button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OtpScreen(email: widget.email),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MindColors.primaryContainer,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Enter Verification Code',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Resend section
                        const Text(
                          "Didn't receive it?",
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: MindColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _isResending ? null : _resend,
                          child: _isResending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MindColors.primary,
                                  ),
                                )
                              : Text(
                                  _resentSuccess ? 'Sent!' : 'Resend Link',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _resentSuccess
                                        ? const Color(0xFF16A34A)
                                        : MindColors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _resentSuccess
                                        ? const Color(0xFF16A34A)
                                        : MindColors.primary,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Footer — Back to Login ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text(
                  'Back to Login',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MindColors.primary,
                  backgroundColor: MindColors.surfaceContainer,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
