import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/coin_catcher.dart';
import '../state/session.dart';

/// Coin Catcher dashboard.
///
/// DartStream integration:
///   - Fetches feature flags from the DartStream platform service at startup
///     (these gate the game's `double_score` / `hard_mode` behavior).
///   - Loads the user profile from the DartStream experience service.
///   - Launches the playable game, which saves the high score via cloud-save
///     and logs `game_started` / `game_over` to the reactive pipeline.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});
  final Session session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_DsEvent> _eventLog = [];

  // Feature flags fetched from the DartStream platform service at startup.
  Set<String> _enabledFlags = {};
  Map<String, dynamic>? _profile;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final client = widget.session.client;
    final dsSession = widget.session.dsSession;
    if (client == null || dsSession == null) return;

    // Fetch feature flags + profile in parallel (same pattern as the
    // founder's DartStream Dash sample app).
    final results = await Future.wait([
      client.platform.listFeatureFlags(dsSession).catchError((_) => <dynamic>[]),
      client.experience.profile(dsSession).catchError((_) => <String, dynamic>{}),
    ]);

    final flags = results[0] as List<dynamic>;
    final profile = results[1] as Map<String, dynamic>;

    final enabled = <String>{};
    for (final flag in flags) {
      if (flag is Map) {
        final key = flag['key'] ?? flag['name'] ?? '';
        final isEnabled = flag['enabled'] == true || flag['status'] == 'active';
        if (isEnabled && key is String && key.isNotEmpty) {
          enabled.add(key);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _enabledFlags = enabled;
      _profile = profile;
      _bootstrapped = true;
      if (enabled.isNotEmpty) {
        _eventLog.insert(0,
            _DsEvent('ds-platform', 'Flags loaded: ${enabled.join(", ")}', success: true));
      } else {
        _eventLog.insert(0, _DsEvent('ds-platform', 'No active flags', warning: true));
      }
      _eventLog.insert(0, _DsEvent('ds-experience', 'Profile loaded', success: true));
    });
  }

  @override
  Widget build(BuildContext context) {
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
                        const SizedBox(height: 32),
                        _gameHeroCard(),
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
            _profile?['displayName'] as String? ?? widget.session.email ?? '',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.session.signOut,
            child: Text(
              'Sign out',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.4),
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
                color: const Color(0xFF4F8EF7).withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text('🪙', style: TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Coin Catcher',
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
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.5),
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
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _gameHeroCard() {
    final flagsOn = _enabledFlags.contains('double_score') ||
        _enabledFlags.contains('hard_mode');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CoinCatcherGame(
            session: widget.session,
            doubleScore: _enabledFlags.contains('double_score'),
            hardMode: _enabledFlags.contains('hard_mode'),
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F8EF7), Color(0xFF7C3AED)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F8EF7).withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Text(
                  'Coin Catcher',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 2),
                      Text(
                        'Play',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Catch falling coins, beat your high score — gameplay is '
              'driven live by DartStream feature flags, cloud-save, and '
              'reactive events.',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (flagsOn) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  if (_enabledFlags.contains('double_score'))
                    _heroFlagChip('double_score'),
                  if (_enabledFlags.contains('hard_mode'))
                    _heroFlagChip('hard_mode'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroFlagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '⚡ $label',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
                color: Colors.white.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: Text(
                  widget.session.tenantId ?? 'Authenticating…',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_profile != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Profile: ',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 11,
                  ),
                ),
                Expanded(
                  child: Text(
                    _profile!['email'] as String? ??
                        _profile!['displayName'] as String? ??
                        widget.session.email ??
                        '—',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_bootstrapped) ...[
            const SizedBox(height: 8),
            Text(
              'FEATURE FLAGS',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            if (_enabledFlags.isEmpty)
              Text(
                'No active flags',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _enabledFlags.map((flag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    flag,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
              ),
          ],
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
            ? const Color(0xFF4F8EF7).withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: s.online
              ? const Color(0xFF4F8EF7).withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.6),
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
              color: const Color(0xFF4F8EF7).withValues(alpha: 0.15),
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
                      : Colors.white.withValues(alpha: 0.5),
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
