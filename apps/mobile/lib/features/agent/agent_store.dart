import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/local_cache.dart';
import '../../core/offline/queue.dart';
import '../sync/sync_service.dart';
import 'scorecard.dart';

const kAgentDossiersCache = 'agent_dossiers';

final agentDossiersRevisionProvider = StateProvider<int>((ref) => 0);

class AgentDossierStore {
  AgentDossierStore(this._cache, this._queue, this._sync, this._ref);

  final LocalCache _cache;
  final OfflineQueue _queue;
  final SyncService _sync;
  final Ref _ref;

  List<Map<String, dynamic>> list() {
    final items = _cache.getList(kAgentDossiersCache);
    items.sort((a, b) {
      final aa = a['createdAt']?.toString() ?? '';
      final bb = b['createdAt']?.toString() ?? '';
      return bb.compareTo(aa);
    });
    return items;
  }

  Future<Map<String, dynamic>> saveAndEnqueue({
    required AgentScoreInput input,
    required AgentScoreResult result,
    String? note,
  }) async {
    final id = OfflineQueue.newId();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final row = {
      'id': id,
      'clientMutationId': id,
      'createdAt': createdAt,
      'synced': false,
      'input': input.toJson(),
      'result': result.toJson(),
      if (note != null && note.isNotEmpty) 'note': note,
      'clientNom': input.clientNom,
      'score': result.score,
      'recommendation': result.recommendation,
      'riskCategory': result.riskCategory,
      'chargeRate': result.chargeRate,
      'montantSoutenableFcfa': result.montantSoutenableFcfa,
      'montantDemandeFcfa': input.montantDemandeFcfa,
    };

    final all = list();
    all.insert(0, row);
    await _cache.putList(kAgentDossiersCache, all);

    await _queue.enqueue(
      QueuedMutation(
        clientMutationId: id,
        kind: 'create_agent_dossier',
        payload: {
          'input': input.toJson(),
          'result': result.toJson(),
          if (note != null && note.isNotEmpty) 'note': note,
        },
        createdAt: createdAt,
      ),
    );
    await _sync.refreshCount();
    _ref.read(agentDossiersRevisionProvider.notifier).state++;
    // ignore: unawaited_futures
    _sync.flush().then((_) async {
      await markSynced(id);
    });
    return row;
  }

  Future<void> markSynced(String id) async {
    final stillQueued = _queue.list().any((m) => m.clientMutationId == id);
    if (stillQueued) return;
    final all = list();
    var changed = false;
    for (final row in all) {
      if (row['id'] == id || row['clientMutationId'] == id) {
        if (row['synced'] != true) {
          row['synced'] = true;
          changed = true;
        }
      }
    }
    if (changed) {
      await _cache.putList(kAgentDossiersCache, all);
      _ref.read(agentDossiersRevisionProvider.notifier).state++;
    }
  }

  Future<void> refreshSyncedFlags() async {
    final all = list();
    var changed = false;
    for (final row in all) {
      final id = row['clientMutationId']?.toString() ?? row['id']?.toString();
      if (id == null) continue;
      final stillQueued = _queue.list().any((m) => m.clientMutationId == id);
      final want = !stillQueued;
      if (row['synced'] != want) {
        row['synced'] = want;
        changed = true;
      }
    }
    if (changed) {
      await _cache.putList(kAgentDossiersCache, all);
      _ref.read(agentDossiersRevisionProvider.notifier).state++;
    }
  }
}

final agentDossierStoreProvider = Provider<AgentDossierStore>((ref) {
  return AgentDossierStore(
    ref.watch(localCacheProvider),
    ref.watch(offlineQueueProvider),
    ref.watch(syncServiceProvider),
    ref,
  );
});

class AgentCoopNotifier extends StateNotifier<String> {
  AgentCoopNotifier(this._cache) : super('') {
    state =
        _cache.getMap(LocalCacheKeys.agentCooperative)?['name']?.toString() ??
            '';
  }

  final LocalCache _cache;

  Future<void> setName(String name) async {
    state = name.trim();
    await _cache.putMap(LocalCacheKeys.agentCooperative, {'name': state});
  }
}

final agentCoopProvider =
    StateNotifierProvider<AgentCoopNotifier, String>((ref) {
  return AgentCoopNotifier(ref.watch(localCacheProvider));
});
