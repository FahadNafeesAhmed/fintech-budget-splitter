import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config.dart';
import '../state/session.dart';

/// Login screen following the DartStream founder sample app pattern:
///   - SegmentedButton to toggle Sign In / Create Account
///   - Delegates auth to Session.signIn() / Session.signUp()
///   - Surfaces Firebase API key warning when key is not injected
///   - No firebase_auth package dependency — uses the `dartstream_client` SDK
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, createAccount }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _clientError;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChange);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChange);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSessionChange() => setState(() {});

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (_mode == _Mode.createAccount &&
        password != _confirmController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _clientError = error);
      return;
    }
    setState(() => _clientError = null);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_mode == _Mode.createAccount) {
      await widget.session.signUp(email, password);
    } else {
      await widget.session.signIn(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.session.status == SessionStatus.signingIn;
    final serverError = widget.session.status == SessionStatus.error
        ? widget.session.errorMessage
        : null;
    final errorMsg = _clientError ?? serverError;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1B3E), Color(0xFF091428)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _logo(),
                  const SizedBox(height: 40),
                  if (!AppConfig.hasFirebaseApiKey) _apiKeyBanner(),
                  if (!AppConfig.hasFirebaseApiKey) const SizedBox(height: 16),
                  _glassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // DartStream pattern: SegmentedButton to toggle modes
                          SegmentedButton<_Mode>(
                            segments: const [
                              ButtonSegment(
                                value: _Mode.signIn,
                                label: Text('Sign In'),
                                icon: Icon(Icons.login_rounded),
                              ),
                              ButtonSegment(
                                value: _Mode.createAccount,
                                label: Text('Create Account'),
                                icon: Icon(Icons.person_add_rounded),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (s) =>
                                setState(() => _mode = s.first),
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF4F8EF7).withOpacity(0.3);
                                }
                                return Colors.white.withOpacity(0.05);
                              }),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.white.withOpacity(0.5);
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _inputField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          if (_mode == _Mode.createAccount) ...[
                            const SizedBox(height: 16),
                            _inputField(
                              controller: _confirmController,
                              label: 'Confirm Password',
                              icon: Icons.lock_outline,
                              obscureText: true,
                            ),
                          ],
                          if (errorMsg != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE53935)
                                        .withOpacity(0.4)),
                              ),
                              child: Text(
                                errorMsg,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFE57373),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: loading ? null : _submit,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F8EF7),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F8EF7)
                                        .withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        loading
                                            ? 'Please wait…'
                                            : _mode == _Mode.signIn
                                                ? 'Sign In'
                                                : 'Create Account',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4F8EF7), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8EF7).withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Budget Splitter',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Powered by DartStream',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF4F8EF7).withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _apiKeyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No Firebase API key found. Run with:\n'
              '--dart-define=FIREBASE_API_KEY=<your_key>',
              style: GoogleFonts.inter(
                color: Colors.amber.shade200,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF4F8EF7), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF4F8EF7), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
