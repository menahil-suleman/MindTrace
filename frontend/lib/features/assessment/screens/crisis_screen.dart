import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../services/assessment_service.dart';

/// "Crisis Detected" screen — matches UI reference image 4 exactly
/// (red-tinted card, warning icon, "Find Help Now" / "I'm Safe, Continue").
///
/// Pushed whenever /chatbot/intake or /assessment/questionnaire returns
/// status == "crisis". Logs the event via POST /assessment/crisis-log
/// (hash only, never raw text) as soon as it opens.
class CrisisScreen extends StatefulWidget {
  /// "keyword" | "phq9_q9" | "semantic" — matches the backend's trigger enum.
  final String trigger;
  final String triggerMessage;

  const CrisisScreen({
    super.key,
    required this.trigger,
    required this.triggerMessage,
  });

  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen> {
  final _assessmentService = AssessmentService();

  static const _helplines = [
    ('Emergency services (Pakistan)', '115'),
    ('Emergency services (int\'l)', '911'),
    ('Umang helpline (free, confidential)', '03117786264'),
  ];

  @override
  void initState() {
    super.initState();
    _logCrisisSilently();
  }

  Future<void> _logCrisisSilently() async {
    try {
      await _assessmentService.logCrisis(
        trigger: widget.trigger,
        triggerMessage: widget.triggerMessage,
      );
    } catch (_) {
      // Audit log failures must never block or fail loudly for the user.
    }
  }

  Future<void> _showHelplines() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reach out now',
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 16),
              for (final (label, number) in _helplines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: MindColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: number);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.call_rounded, color: MindColors.primary),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: Theme.of(sheetContext).textTheme.bodyMedium),
                                  Text(number,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MindColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Exit', style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: MindColors.errorContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_rounded, color: MindColors.error, size: 36),
                            const SizedBox(height: 12),
                            Text('CRISIS DETECTED',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: MindColors.error,
                                      letterSpacing: 0.5,
                                    )),
                            const SizedBox(height: 6),
                            Text("We're concerned about your safety.",
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: MindColors.error,
                                      fontSize: 22,
                                    )),
                            const SizedBox(height: 14),
                            Text(
                              'It sounds like you may be going through a very difficult time.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "If you're in immediate danger, please contact emergency "
                                    'services or someone you trust right away.',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showHelplines,
                                    icon: const Icon(Icons.call_rounded, size: 18),
                                    label: const Text('Find Help Now'),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: MindColors.primary,
                                      side: const BorderSide(color: MindColors.primary, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text("I'm Safe, Continue"),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 20, color: MindColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You are not alone. Help is available 24/7.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: MindColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
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
