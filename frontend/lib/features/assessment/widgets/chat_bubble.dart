import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Bot message bubble — white card, brain icon + "MindTrace" sender label.
/// Matches images 7/8/9's left-aligned assistant bubbles.
class BotChatBubble extends StatelessWidget {
  final String message;
  final String? timestamp;

  const BotChatBubble({super.key, required this.message, this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MindColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: MindColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_alt, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text('MindTrace',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: MindColors.onSurface)),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            if (timestamp != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(timestamp!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: MindColors.onSurfaceVariant)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// User message bubble — filled green pill, right-aligned "You" label.
/// Matches images 5/8's right-aligned user bubbles.
class UserChatBubble extends StatelessWidget {
  final String message;
  final String? timestamp;

  const UserChatBubble({super.key, required this.message, this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: MindColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('You', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(message,
                style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.right),
            if (timestamp != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(timestamp!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: MindColors.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 14, color: MindColors.primary),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three-dot "MindTrace is typing" indicator (image 4/AI-typing-state).
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MindTrace is typing',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: MindColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: MindColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: MindColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
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
