import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Radio-style row used for questionnaire answers — "Several days (1)" etc.
/// Matches images 5/6.
class AnswerOptionTile extends StatelessWidget {
  final String label;
  final String valueSuffix; // e.g. "(1)"
  final bool selected;
  final VoidCallback onTap;

  const AnswerOptionTile({
    super.key,
    required this.label,
    required this.valueSuffix,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? MindColors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? MindColors.surfaceContainerLow : MindColors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? MindColors.primary : MindColors.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          )),
                ),
                Text(valueSuffix, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped quick-reply chip — "Student" / "Working Professional" row.
/// Matches image 3 (User Answer screen).
class QuickReplyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const QuickReplyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MindColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? MindColors.primary : MindColors.outlineVariant),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? Colors.white : MindColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
