import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _splitResultProvider =
    StateNotifierProvider<_SplitNotifier, _SplitState>(
  (_) => _SplitNotifier(),
);

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

sealed class _SplitState {}

class _Idle extends _SplitState {}

class _Loading extends _SplitState {}

class _Success extends _SplitState {
  _Success(this.result);
  final SplitResult result;
}

class _Error extends _SplitState {
  _Error(this.message);
  final String message;
}

class _SplitNotifier extends StateNotifier<_SplitState> {
  _SplitNotifier() : super(_Idle());

  Future<void> calculate(double total, int people) async {
    state = _Loading();
    // Small artificial delay so the loading animation is visible
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      final result = BudgetCalculator.calculate(
        Transaction(totalAmount: total, numberOfPeople: people),
      );
      state = _Success(result);
    } on ArgumentError catch (e) {
      state = _Error(e.message.toString());
    } catch (_) {
      state = _Error('Something went wrong. Please try again.');
    }
  }

  void reset() => state = _Idle();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _peopleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _buttonAnim;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _buttonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _buttonAnim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _peopleController.dispose();
    _buttonAnim.dispose();
    super.dispose();
  }

  Future<void> _onCalculate() async {
    if (!_formKey.currentState!.validate()) return;

    await _buttonAnim.forward();
    await _buttonAnim.reverse();

    final total = double.parse(_amountController.text);
    final people = int.parse(_peopleController.text);
    await ref.read(_splitResultProvider.notifier).calculate(total, people);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<_SplitState>(_splitResultProvider, (_, next) {
      if (next is _Error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFE53935),
            content: Text(next.message,
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    });

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
                  _Header(),
                  const SizedBox(height: 40),
                  _GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InputField(
                            controller: _amountController,
                            label: 'Total Bill Amount',
                            prefix: '\$',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter a bill amount';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Enter a valid number';
                              }
                              if (double.parse(v) <= 0) {
                                return 'Amount must be greater than zero';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _InputField(
                            controller: _peopleController,
                            label: 'Number of People',
                            prefix: '#',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter number of people';
                              }
                              final n = int.tryParse(v);
                              if (n == null || n <= 0) {
                                return 'Must be at least 1 person';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          _CalculateButton(
                            scale: _buttonScale,
                            onTap: _onCalculate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ResultPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
              )
            ],
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 32),
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
          'Split any bill instantly',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.prefix,
    required this.keyboardType,
    required this.validator,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String prefix;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 14),
        prefixText: '$prefix  ',
        prefixStyle: GoogleFonts.inter(
            color: const Color(0xFF4F8EF7),
            fontWeight: FontWeight.w600,
            fontSize: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4F8EF7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        errorStyle: GoogleFonts.inter(color: const Color(0xFFE57373)),
      ),
    );
  }
}

class _CalculateButton extends ConsumerWidget {
  const _CalculateButton({required this.scale, required this.onTap});

  final Animation<double> scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_splitResultProvider);
    final isLoading = state is _Loading;

    return ScaleTransition(
      scale: scale,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F8EF7), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F8EF7).withOpacity(isLoading ? 0.2 : 0.4),
                blurRadius: isLoading ? 8 : 20,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Calculate',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_splitResultProvider);

    if (state is! _Success) return const SizedBox.shrink();

    final result = state.result;
    final amount = result.amountPerPerson.toStringAsFixed(2);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: _GlassCard(
        child: Column(
          children: [
            Text(
              'Each person pays',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF4F8EF7), Color(0xFF7C3AED)],
              ).createShader(bounds),
              child: Text(
                '\$$amount',
                style: GoogleFonts.inter(
                  fontSize: _fontSize(amount.length),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '\$${result.totalAmount.toStringAsFixed(2)} ÷ ${result.numberOfPeople} people',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _fontSize(int charCount) {
    if (charCount <= 5) return 56;
    if (charCount <= 8) return 44;
    return 34;
  }
}
