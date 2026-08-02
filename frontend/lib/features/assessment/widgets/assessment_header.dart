import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Matches the "Assessment / Step X of Y" header + progress bar seen
/// across every screen in the UI reference images.
class AssessmentHeader extends StatelessWidget {
  final int stepIndex; // 1-based
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onExit;

  const AssessmentHeader({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    this.onBack,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSteps == 0 ? 0.0 : (stepIndex / totalSteps).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: onBack != null
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_left, size: 28),
                      onPressed: onBack,
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text('Assessment', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Step $stepIndex of $totalSteps',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MindColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: TextButton(
                onPressed: onExit,
                child: Text('Exit', style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: MindColors.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(MindColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('$percent%', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
