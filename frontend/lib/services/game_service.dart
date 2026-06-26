import 'package:dartstream_client/dartstream_client.dart';

import '../config.dart';

/// Wires the Coin Catcher game to live DartStream services:
///   - persistence: high score in a single cloud-save snapshot (LWW),
///   - reactive: `game_started` / `game_over` events on real gameplay.
///
/// Cloud-save is a single resumable snapshot (slot `game_state`), not an
/// append log — each save overwrites the slot with the latest high score.
class GameService {
  GameService(this.client, this.session);

  final DartStreamClient client;
  final DartStreamSession session;

  static const String slotKey = 'game_state';
  static const DartStreamScope scope =
      DartStreamScope(projectId: AppConfig.projectId);

  /// Loads the persisted high score (0 if none / unreachable).
  Future<int> loadHighScore() async {
    final snapshot = await client.experience.loadCloudSave(
      session,
      scope: scope,
      slotKey: slotKey,
    );
    final payload = snapshot?['payload'] ?? snapshot;
    final value = payload is Map ? payload['high_score'] : null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Persists a new high score (single-slot last-write-wins).
  Future<void> saveHighScore(int score) {
    return client.experience.saveCloudSave(
      session,
      scope: scope,
      slotKey: slotKey,
      payload: {'high_score': score},
    );
  }

  /// Logs the start of a game to the reactive pipeline.
  Future<void> logGameStarted() {
    return client.reactive.logEvent(
      session,
      eventType: 'game_started',
      payload: const {},
    );
  }

  /// Logs the end of a game (with final score) to the reactive pipeline.
  Future<void> logGameOver(int score) {
    return client.reactive.logEvent(
      session,
      eventType: 'game_over',
      payload: {'score': score},
    );
  }
}
