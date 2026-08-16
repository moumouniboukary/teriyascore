import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/offline/local_cache.dart';
import '../../core/offline/queue.dart';

final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  throw UnimplementedError('OfflineQueue must be overridden in main');
});

final syncPendingProvider = StateProvider<int>((ref) => 0);
final syncErrorProvider = StateProvider<String?>((ref) => null);

class SyncService {
  SyncService(this._api, this._queue, this._cache, this._ref);

  final ApiClient _api;
  final OfflineQueue _queue;
  final LocalCache _cache;
  final Ref _ref;

  Object? _connectivitySub;
  bool _flushing = false;

  Future<void> refreshCount() async {
    _ref.read(syncPendingProvider.notifier).state = _queue.count;
  }

  /// Précharge les écrans clés pour qu'ils restent utilisables hors ligne.
  Future<void> warmCaches() async {
    Future<void> warmList(String path, String cacheKey) async {
      try {
        final list = await _api.get<List>(path, parse: (d) => d as List);
        final mapped =
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await _cache.putList(cacheKey, mapped);
      } catch (_) {
        if (!_cache.hasKey(cacheKey)) {
          await _cache.putList(cacheKey, const []);
        }
      }
    }

    Future<void> warmMap(String path, String cacheKey) async {
      try {
        final map = await _api.get<Map<String, dynamic>>(
          path,
          parse: (d) => Map<String, dynamic>.from(d as Map),
        );
        await _cache.putMap(cacheKey, map);
      } catch (_) {
        /* conserve le cache existant */
      }
    }

    Future<void> warmStock() async {
      try {
        final res = await _api.get<Map<String, dynamic>>(
          '/stock/articles',
          parse: (d) => Map<String, dynamic>.from(d as Map),
        );
        final items = ((res['items'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await _cache.putList(LocalCacheKeys.stock, items);
      } catch (_) {
        if (!_cache.hasKey(LocalCacheKeys.stock)) {
          await _cache.putList(LocalCacheKeys.stock, const []);
        }
      }
    }

    await Future.wait([
      warmList('/operations', LocalCacheKeys.operations),
      warmList('/clients', LocalCacheKeys.clients),
      warmStock(),
      warmList('/tontines', LocalCacheKeys.tontines),
      warmList('/notifications', LocalCacheKeys.notifications),
      warmMap('/dashboard', LocalCacheKeys.dashboard),
      warmMap('/score', LocalCacheKeys.score),
      warmMap('/me', LocalCacheKeys.profile),
    ]);
  }

  /// Écoute les changements de connectivité pour relancer [flush]
  /// automatiquement dès le retour du réseau. Idempotent.
  void startAutoSync() {
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online) flush();
    });
  }

  void stopAutoSync() {
    (_connectivitySub as dynamic)?.cancel();
    _connectivitySub = null;
  }

  /// Confirme les dossiers sur l’appareil (pas d’appel cloud).
  /// Retourne le nombre d’éléments retirés de la file.
  Future<int> acknowledgeLocal() async {
    final ids = _queue.list().map((m) => m.clientMutationId).toList();
    if (ids.isNotEmpty) {
      await _queue.clearAccepted(ids);
    }
    _ref.read(syncErrorProvider.notifier).state = null;
    await refreshCount();
    return ids.length;
  }

  /// Ne contacte plus le cloud : Render n’accepte pas les dossiers agent.
  /// [userRequested] : bouton Envoi → enregistrement local.
  Future<void> flush({bool userRequested = false}) async {
    if (_flushing) return;
    _flushing = true;
    try {
      _ref.read(syncErrorProvider.notifier).state = null;
      if (userRequested) {
        await acknowledgeLocal();
        return;
      }
      await refreshCount();
    } finally {
      _flushing = false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(apiClientProvider),
    ref.watch(offlineQueueProvider),
    ref.watch(localCacheProvider),
    ref,
  );
});
