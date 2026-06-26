import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/game_service.dart';
import '../state/session.dart';

/// Coin Catcher — a playable game wired to live DartStream services.
///
/// DartStream integration:
///   - Feature flags drive gameplay: `double_score` (2x points) and
///     `hard_mode` (faster coins) are read from the platform service.
///   - High score persists via cloud-save (single snapshot, slot `game_state`).
///   - `game_started` / `game_over` events log to the reactive pipeline.
class CoinCatcherGame extends StatefulWidget {
  const CoinCatcherGame({
    super.key,
    required this.session,
    required this.doubleScore,
    required this.hardMode,
  });

  final Session session;

  /// Feature flag `double_score` — coins are worth 2x when enabled.
  final bool doubleScore;

  /// Feature flag `hard_mode` — coins fall faster when enabled.
  final bool hardMode;

  @override
  State<CoinCatcherGame> createState() => _CoinCatcherGameState();
}

class _Coin {
  _Coin(this.id, this.x, this.y);
  final int id;
  final double x; // 0..1 fraction of width
  double y; // 0..1 fraction of height
}

enum _GameStatus { ready, playing, over }

class _CoinCatcherGameState extends State<CoinCatcherGame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = Random();

  _GameStatus _status = _GameStatus.ready;
  final List<_Coin> _coins = [];
  int _nextId = 0;
  int _score = 0;
  int _lives = 3;
  int _highScore = 0;
  bool _loadingHigh = true;

  Duration _lastTick = Duration.zero;
  double _spawnTimer = 0;

  GameService? get _gameService {
    final c = widget.session.client;
    final s = widget.session.dsSession;
    if (c == null || s == null) return null;
    return GameService(c, s);
  }

  // Flag-driven tuning.
  double get _fallSpeed => widget.hardMode ? 0.55 : 0.34; // fraction/sec
  double get _spawnInterval => widget.hardMode ? 0.7 : 1.0; // seconds
  int get _coinValue => widget.doubleScore ? 20 : 10;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadHighScore();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final svc = _gameService;
    if (svc == null) {
      setState(() => _loadingHigh = false);
      return;
    }
    try {
      final hs = await svc.loadHighScore();
      if (!mounted) return;
      setState(() {
        _highScore = hs;
        _loadingHigh = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHigh = false);
    }
  }

  void _start() {
    setState(() {
      _status = _GameStatus.playing;
      _coins.clear();
      _score = 0;
      _lives = 3;
      _spawnTimer = 0;
      _lastTick = Duration.zero;
    });
    _ticker.start();
    _gameService?.logGameStarted().catchError((_) {});
  }

  void _onTick(Duration elapsed) {
    if (_status != _GameStatus.playing) return;
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    // Spawn.
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _coins.add(_Coin(_nextId++, 0.08 + _rng.nextDouble() * 0.84, -0.05));
    }

    // Advance + detect misses.
    var lostLife = false;
    for (final coin in _coins) {
      coin.y += _fallSpeed * dt;
    }
    _coins.removeWhere((c) {
      if (c.y >= 1.05) {
        lostLife = true;
        return true;
      }
      return false;
    });

    if (lostLife) {
      _lives -= 1;
      if (_lives <= 0) {
        _endGame();
        return;
      }
    }

    setState(() {});
  }

  void _collect(_Coin coin) {
    if (_status != _GameStatus.playing) return;
    setState(() {
      _coins.remove(coin);
      _score += _coinValue;
    });
  }

  Future<void> _endGame() async {
    _ticker.stop();
    final finalScore = _score;
    setState(() => _status = _GameStatus.over);

    final svc = _gameService;
    if (svc == null) return;
    svc.logGameOver(finalScore).catchError((_) {});
    if (finalScore > _highScore) {
      setState(() => _highScore = finalScore);
      svc.saveHighScore(finalScore).catchError((_) {});
    }
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
              _header(),
              _scoreBar(),
              Expanded(child: _playArea()),
              _flagBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            'Coin Catcher',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _loadingHigh ? 'Best: …' : 'Best: $_highScore',
            style: GoogleFonts.inter(
              color: const Color(0xFF4F8EF7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Score: $_score',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.favorite,
                  size: 20,
                  color: i < _lives
                      ? const Color(0xFFE53935)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    if (_status == _GameStatus.playing)
                      ..._coins.map((coin) => Positioned(
                            left: coin.x * w - 22,
                            top: coin.y * h - 22,
                            child: GestureDetector(
                              onTap: () => _collect(coin),
                              child: _coinWidget(),
                            ),
                          )),
                    if (_status != _GameStatus.playing)
                      Center(child: _overlay()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _coinWidget() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFFA000)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: const Center(
        child: Text('\$', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20)),
      ),
    );
  }

  Widget _overlay() {
    final isOver = _status == _GameStatus.over;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isOver ? 'Game Over' : 'Coin Catcher',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOver
              ? 'You collected \$$_score'
              : 'Tap the falling coins before they drop.\n3 misses and it\'s game over.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _start,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF4F8EF7), Color(0xFF7C3AED)],
              ),
            ),
            child: Text(
              isOver ? 'Play Again' : 'Start',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _flagBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Live flags: ',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
          _flagChip('double_score', widget.doubleScore),
          const SizedBox(width: 6),
          _flagChip('hard_mode', widget.hardMode),
        ],
      ),
    );
  }

  Widget _flagChip(String label, bool on) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (on ? const Color(0xFF00E676) : Colors.white)
            .withValues(alpha: on ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (on ? const Color(0xFF00E676) : Colors.white)
              .withValues(alpha: on ? 0.3 : 0.12),
        ),
      ),
      child: Text(
        '$label ${on ? "ON" : "off"}',
        style: GoogleFonts.inter(
          color: on ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
