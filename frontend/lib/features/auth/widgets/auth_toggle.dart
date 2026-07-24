import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// The sliding Login / Sign Up toggle that matches the HTML design.
class AuthToggle extends StatelessWidget {
  /// 0 = Login selected, 1 = Sign Up selected
  final int selected;
  final ValueChanged<int> onChanged;

  const AuthToggle({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MindColors.toggleBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          // Sliding pill
          AnimatedAlign(
            alignment: selected == 0 ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: MindColors.toggleActive,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              _ToggleOption(
                label: 'Login',
                isActive: selected == 0,
                onTap: () => onChanged(0),
              ),
              _ToggleOption(
                label: 'Sign Up',
                isActive: selected == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : MindColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
