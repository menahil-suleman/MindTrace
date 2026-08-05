import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_toggle.dart';
import '../widgets/clinical_text_field.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  /// Called when the user taps "Login" — the parent [AuthScreen] slides
  /// back to the login page instead of doing a route push.
  final VoidCallback? onSwitchToLogin;

  const SignupScreen({super.key, this.onSwitchToLogin});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Controllers
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // UI state
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _ageConfirmed = false;
  String? _selectedGender;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedDob;

  // Gender options
  static const _genderOptions = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('non-binary', 'Non-binary'),
    ('prefer-not-to-say', 'Prefer not to say'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 5),
      helpText: 'SELECT DATE OF BIRTH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: MindColors.primaryContainer,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: MindColors.onSurface,
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: MindColors.primaryContainer,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  // ── Form submit ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (!_ageConfirmed) {
      setState(() => _errorMessage =
          'Please confirm you are 18+ or have parental consent.');
      return;
    }

    if (_selectedDob == null) {
      setState(() => _errorMessage = 'Please select your date of birth.');
      return;
    }

    // Format as YYYY-MM-DD for the API
    final dob = '${_selectedDob!.year.toString().padLeft(4, '0')}-'
        '${_selectedDob!.month.toString().padLeft(2, '0')}-'
        '${_selectedDob!.day.toString().padLeft(2, '0')}';

    setState(() => _isLoading = true);

    try {
      await _authService.signup(
        email: _emailCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        dateOfBirth: dob,
        gender: _selectedGender,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created! Please log in.'),
          backgroundColor: MindColors.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          'Could not connect to server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCE6DE), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D4B37).withValues(alpha: 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 28),
                      AuthToggle(
                        selected: 1,
                        onChanged: (index) {
                          if (index == 0) {
                            if (widget.onSwitchToLogin != null) {
                              widget.onSwitchToLogin!();
                            } else {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Sign Up',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: MindColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Join MindTrace to access precision mental health monitoring.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: MindColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ClinicalTextField(
                        label: 'Email Address',
                        placeholder: 'example@medical.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ClinicalTextField(
                        label: 'Username',
                        placeholder: 'Choose a unique username',
                        controller: _usernameCtrl,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Username is required';
                          }
                          if (v.trim().length < 3) {
                            return 'Minimum 3 characters';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                            return 'Only letters, numbers and underscores';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ClinicalTextField(
                        label: 'Password',
                        placeholder: '••••••••',
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) return 'Minimum 8 characters';
                          return null;
                        },
                        suffixIcon: _VisibilityToggle(
                          visible: !_obscurePassword,
                          onToggle: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClinicalTextField(
                        label: 'Confirm Password',
                        placeholder: '••••••••',
                        controller: _confirmPassCtrl,
                        obscureText: _obscureConfirm,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        suffixIcon: _VisibilityToggle(
                          visible: !_obscureConfirm,
                          onToggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDobPicker(),
                      const SizedBox(height: 16),
                      _buildGenderDropdown(),
                      const SizedBox(height: 20),
                      _buildAgeCheckbox(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: MindColors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: Color(0xFF93000A),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already a member? ',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: MindColors.onSurfaceVariant,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (widget.onSwitchToLogin != null) {
                                widget.onSwitchToLogin!();
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              }
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: MindColors.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Column(
          children: [
            Icon(Icons.psychology_outlined,
                size: 64, color: MindColors.primary),
            SizedBox(height: 8),
            Text(
              'MindTrace',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: MindColors.primary,
              ),
            ),
            Text(
              'Clinical Mental Health Systems',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: MindColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDobPicker() {
    final hasDate = _selectedDob != null;
    final displayText = hasDate
        ? '${_selectedDob!.day.toString().padLeft(2, '0')} / '
            '${_selectedDob!.month.toString().padLeft(2, '0')} / '
            '${_selectedDob!.year}'
        : 'DD / MM / YYYY';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DATE OF BIRTH',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MindColors.onSurface,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: MindColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MindColors.outline, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: hasDate
                          ? MindColors.onSurface
                          : MindColors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: MindColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GENDER SELECTION',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MindColors.onSurface,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _selectedGender,
          hint: const Text(
            'Select gender identity',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              color: Color(0x66424843),
            ),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MindColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide:
                  const BorderSide(color: MindColors.outline, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide:
                  const BorderSide(color: MindColors.outline, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: MindColors.primary, width: 2),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          icon:
              const Icon(Icons.expand_more, color: MindColors.onSurfaceVariant),
          items: _genderOptions
              .map((g) => DropdownMenuItem(
                    value: g.$1,
                    child: Text(
                      g.$2,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: MindColors.onSurface,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
      ],
    );
  }

  Widget _buildAgeCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _ageConfirmed,
            onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
            shape: const CircleBorder(),
            activeColor: MindColors.primaryContainer,
            side: const BorderSide(color: MindColors.outline, width: 1.5),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'I confirm I am 18+ or have parental consent to use MindTrace.',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: MindColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: MindColors.primaryContainer,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              MindColors.primaryContainer.withValues(alpha: 0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Create Account',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.28,
                ),
              ),
      ),
    );
  }
}

// ── Eye-toggle button ─────────────────────────────────────────────────────────
class _VisibilityToggle extends StatelessWidget {
  final bool visible;
  final VoidCallback onToggle;

  const _VisibilityToggle({required this.visible, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: MindColors.onSurfaceVariant,
        size: 20,
      ),
      onPressed: onToggle,
    );
  }
}
