import 'dart:ui';

import 'package:dartstream_client/dartstream_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';

import '../config.dart';
import '../state/session.dart';

/// Main budget splitter screen.
///
/// DartStream integration:
///   - Reads feature flag `enable_rounding` from DartStream platform service.
///     When enabled, the result is rounded to 2 decimal places.
///   - Saves every split to DartStream persistence (cloud-save slot: split_history).
///   - Logs `split_calculated` / `split_error` events to DartStream reactive pipeline.
///   - Math still runs locally via shared_models BudgetCalculator (intentional naive bug kept).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});
  final Session session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _peopleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _SplitState _state = _Idle();
  final List<_DsEvent> _eventLog = [];

  late final AnimationController _buttonAnim;
  late final Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _buttonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
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

    setState(() => _state = _Loading());

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final total = double.parse(_amountController.text);
      final people = int.parse(_peopleController.text);
      final transaction = Transaction(
        totalAmount: total,
        numberOfPeople: people,
      );

      final result = BudgetCalculator.calculate(transaction);
      setState(() => _state = _Success(result));

      // DartStream: append to cloud-save history + log reactive event.
      // Cloud-save snapshots are single-slot last-write-wins, so we
      // read-modify-write the full history list back into the slot.
      final client = widget.session.client;
      final dsSession = widget.session.dsSession;
      if (client != null && dsSession != null) {
        const scope = DartStreamScope(projectId: AppConfig.projectId);
        final entry = <String, dynamic>{
          'total_amount': transaction.totalAmount,
          'number_of_people': transaction.numberOfPeople,
          'description': transaction.description,
          'amount_per_person': result.amountPerPerson,
          'calculated_at': DateTime.now().toIso8601String(),
        };

        setState(() => _eventLog.insert(0, _DsEvent('ds-experience', 'Read-modify-write → split_history')));
        () async {
          try {
            final snapshot = await client.experience.loadCloudSave(
              dsSession,
              scope: scope,
              slotKey: 'split_history',
            );
            final existing = _extractItems(snapshot);
            existing.insert(0, entry);
            await client.experience.saveCloudSave(
              dsSession,
              scope: scope,
              slotKey: 'split_history',
              payload: {'items': existing},
            );
            if (!mounted) return;
            setState(() => _eventLog.insert(0, _DsEvent('ds-experience', 'Saved ✓ (${existing.length} entries)', success: true)));
          } catch (e) {
            if (!mounted) return;
            setState(() => _eventLog.insert(0, _DsEvent('ds-experience', _errorLine(e), warning: true)));
          }
        }();

        setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', 'Logging split_calculated event')));
        client.reactive.logEvent(
          dsSession,
          eventType: 'split_calculated',
          payload: {
            'total_amount': transaction.totalAmount,
            'number_of_people': transaction.numberOfPeople,
            'amount_per_person': result.amountPerPerson,
            'description': transaction.description,
          },
        ).then((_) {
          if (!mounted) return;
          setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', 'Event logged ✓', success: true)));
        }).catchError((e) {
          if (!mounted) return;
          setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', _errorLine(e), warning: true)));
        });
      }
    } on ArgumentError catch (e) {
      final msg = e.message.toString();
      setState(() => _state = _Error(msg));
      final client = widget.session.client;
      final dsSession = widget.session.dsSession;
      if (client != null && dsSession != null) {
        setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', 'Logging split_error event')));
        client.reactive.logEvent(
          dsSession,
          eventType: 'split_error',
          payload: {'error': msg},
        ).then((_) {
          if (!mounted) return;
          setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', 'split_error logged ✓', success: true)));
        }).catchError((e) {
          if (!mounted) return;
          setState(() => _eventLog.insert(0, _DsEvent('ds-reactive', _errorLine(e), warning: true)));
        });
      }
    } catch (_) {
      setState(() => _state = _Error('Something went wrong. Please try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state is _Error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_state is _Error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFE53935),
              content: Text(
                (_state as _Error).message,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
          setState(() => _state = _Idle());
        }
      });
    }

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
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _header(),
                        const SizedBox(height: 40),
                        _glassCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _inputField(
                                  controller: _amountController,
                                  label: 'Total Bill Amount',
                                  prefix: '\$',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
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
                                _inputField(
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
                                _calculateButton(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_state is _Success) _resultPanel(_state as _Success),
                        const SizedBox(height: 32),
                        _dartstreamPanel(),
                      ],
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4F8EF7),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'DartStream',
            style: GoogleFonts.inter(
              color: const Color(0xFF4F8EF7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            widget.session.email ?? '',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.session.signOut,
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
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
    required String prefix,
    required TextInputType keyboardType,
    required FormFieldValidator<String> validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.6), fontSize: 14),
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
          borderSide:
              const BorderSide(color: Color(0xFF4F8EF7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        errorStyle: GoogleFonts.inter(color: const Color(0xFFE57373)),
      ),
    );
  }

  Widget _calculateButton() {
    final isLoading = _state is _Loading;
    return ScaleTransition(
      scale: _buttonScale,
      child: GestureDetector(
        onTap: isLoading ? null : _onCalculate,
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
                color: const Color(0xFF4F8EF7)
                    .withOpacity(isLoading ? 0.2 : 0.4),
                blurRadius: isLoading ? 8 : 20,
                offset: const Offset(0, 6),
              ),
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

  Widget _resultPanel(_Success state) {
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
      child: _glassCard(
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
            const SizedBox(height: 8),
            // DartStream badge — shows data was logged to the reactive pipeline
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4F8EF7),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Logged to DartStream',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4F8EF7).withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
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

  /// Reads the history list from a `loadCloudSave` snapshot. Cloud-save
  /// stores a single Map; we wrap the history under `items` on write.
  List<Map<String, dynamic>> _extractItems(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return <Map<String, dynamic>>[];
    final payload = snapshot['payload'] ?? snapshot;
    final items = (payload is Map ? payload['items'] : null);
    if (items is List) {
      return items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Surfaces the real failure (status code + body or exception message)
  /// instead of a vague "dev env" warning, so demo bugs aren't hidden.
  String _errorLine(Object e) {
    if (e is DartStreamApiException) {
      final body = e.body.length > 120 ? '${e.body.substring(0, 120)}…' : e.body;
      return 'HTTP ${e.statusCode}: $body';
    }
    return e.toString();
  }

  Widget _dartstreamPanel() {
    final services = [
      _ServiceStatus('ds-auth', true),
      _ServiceStatus('ds-platform', true),
      _ServiceStatus('ds-experience', true),
      _ServiceStatus('ds-reactive', true),
    ];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4F8EF7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'DARTSTREAM ENGINE',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4F8EF7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Service status row
          Row(
            children: services
                .map((s) => Expanded(child: _serviceChip(s)))
                .toList(),
          ),
          if (_eventLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'REACTIVE EVENT LOG',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...(_eventLog.take(6).map((e) => _eventRow(e))),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Tenant: ',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: Text(
                  widget.session.tenantId ?? 'Authenticating…',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceChip(_ServiceStatus s) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: s.online
            ? const Color(0xFF4F8EF7).withOpacity(0.12)
            : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: s.online
              ? const Color(0xFF4F8EF7).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.online ? const Color(0xFF00E676) : Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.name,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _eventRow(_DsEvent e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4F8EF7).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              e.service,
              style: GoogleFonts.inter(
                color: const Color(0xFF4F8EF7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            e.message,
            style: GoogleFonts.inter(
              color: e.success
                  ? const Color(0xFF00E676)
                  : e.warning
                      ? Colors.amber.shade300
                      : Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DsEvent {
  _DsEvent(this.service, this.message, {this.success = false, this.warning = false});
  final String service;
  final String message;
  final bool success;
  final bool warning;
}

class _ServiceStatus {
  _ServiceStatus(this.name, this.online);
  final String name;
  final bool online;
}
