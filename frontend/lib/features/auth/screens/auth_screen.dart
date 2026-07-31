import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';

/// Single entry-point for the auth flow.
///
/// Wraps [LoginScreen] and [SignupScreen] in a [PageView] so the switch
/// between the two tabs is a smooth, physics-driven horizontal slide —
/// no route push/pop flicker.
class AuthScreen extends StatefulWidget {
  /// Start on Login (0) or Sign Up (1).
  final int initialIndex;

  const AuthScreen({super.key, this.initialIndex = 0});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void switchTo(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      // Disable swipe — navigation is only through the toggle/links
      physics: const NeverScrollableScrollPhysics(),
      children: [
        LoginScreen(onSwitchToSignup: () => switchTo(1)),
        SignupScreen(onSwitchToLogin: () => switchTo(0)),
      ],
    );
  }
}
