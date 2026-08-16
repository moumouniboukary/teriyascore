import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/client.dart';
import '../../core/offline/local_cache.dart';

/// Client informel (débiteur) rattaché à une créance.
class ClientInfo {
  const ClientInfo({required this.id, required this.nom, this.telephone});

  final String id;
  final String nom;
  final String? telephone;

  factory ClientInfo.fromMap(Map<String, dynamic> m) => ClientInfo(
        id: m['id'].toString(),
        nom: m['nom']?.toString() ?? 'Client',
        telephone: m['telephone']?.toString(),
      );
}

/// Révision globale des données du cahier.
/// Incrémentée à chaque changement (création, règlement, synchronisation).
/// Les écrans qui l'observent se rechargent automatiquement.
final ledgerRevisionProvider = StateProvider<int>((ref) => 0);

/// Liste des clients — API puis cache local hors ligne.
final clientsProvider = FutureProvider.autoDispose<List<ClientInfo>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final api = ref.watch(apiClientProvider);
  final cache = ref.watch(localCacheProvider);
  try {
    final list = await api.get<List>('/clients', parse: (d) => d as List);
    final mapped = list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    await cache.putList(LocalCacheKeys.clients, mapped);
    return mapped.map(ClientInfo.fromMap).toList();
  } catch (_) {
    return cache.getList(LocalCacheKeys.clients).map(ClientInfo.fromMap).toList();
  }
});

class ClientsRepository {
  ClientsRepository(this._api);

  final ApiClient _api;

  Future<ClientInfo> create({required String nom, String? telephone}) async {
    final m = await _api.post<Map<String, dynamic>>(
      '/clients',
      data: {
        'nom': nom,
        if (telephone != null && telephone.trim().isNotEmpty)
          'telephone': telephone.trim(),
      },
      parse: (d) => Map<String, dynamic>.from(d as Map),
    );
    return ClientInfo.fromMap(m);
  }

  Future<void> delete(String id) => _api.delete('/clients/$id');
}

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(ref.watch(apiClientProvider)),
);
