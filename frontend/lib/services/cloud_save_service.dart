import 'package:dartstream_client/dartstream_client.dart';

import '../config.dart';

/// Encapsulates the DartStream cloud-save integration for split history,
/// following the structure of the approved FocusStream sample's
/// `CloudSaveService`.
///
/// Cloud-save snapshots are a single-slot, last-write-wins store, so a running
/// history is kept by read-modify-writing the whole list back into the slot.
class CloudSaveService {
  CloudSaveService(this.client, this.session);

  final DartStreamClient client;
  final DartStreamSession session;

  static const String slotKey = 'split_history';
  static const DartStreamScope scope =
      DartStreamScope(projectId: AppConfig.projectId);

  /// Loads the current history, prepends [entry], and writes it back.
  /// Returns the new total entry count.
  Future<int> appendSplit(Map<String, dynamic> entry) async {
    final snapshot = await client.experience.loadCloudSave(
      session,
      scope: scope,
      slotKey: slotKey,
    );
    final items = _extractItems(snapshot)..insert(0, entry);
    await client.experience.saveCloudSave(
      session,
      scope: scope,
      slotKey: slotKey,
      payload: {'items': items},
    );
    return items.length;
  }

  /// Loads the saved split history (most-recent first).
  Future<List<Map<String, dynamic>>> loadHistory() async {
    final snapshot = await client.experience.loadCloudSave(
      session,
      scope: scope,
      slotKey: slotKey,
    );
    return _extractItems(snapshot);
  }

  /// Tolerant extraction of the items list from the snapshot envelope, which
  /// may be `{payload: {items: [...]}}` or just `{items: [...]}`.
  List<Map<String, dynamic>> _extractItems(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return <Map<String, dynamic>>[];
    final payload = snapshot['payload'] ?? snapshot;
    final items = payload is Map ? payload['items'] : null;
    if (items is List) {
      return items
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }
}
