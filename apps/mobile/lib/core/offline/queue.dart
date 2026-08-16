import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class QueuedMutation {
  QueuedMutation({
    required this.clientMutationId,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
    this.failReason,
    this.ownerUserId,
  });

  final String clientMutationId;
  final String kind;
  final Map<String, dynamic> payload;
  final String createdAt;

  /// pending | failed — les failed ne sont plus rejouées automatiquement.
  final String status;
  final String? failReason;
  /// Compte propriétaire — évite de mélanger les files entre agents.
  final String? ownerUserId;

  Map<String, dynamic> toJson() => {
        'clientMutationId': clientMutationId,
        'kind': kind,
        'payload': payload,
        'createdAt': createdAt,
        'status': status,
        if (failReason != null) 'failReason': failReason,
        if (ownerUserId != null) 'ownerUserId': ownerUserId,
      };

  factory QueuedMutation.fromJson(Map<String, dynamic> json) {
    return QueuedMutation(
      clientMutationId: json['clientMutationId'] as String,
      kind: json['kind'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: json['createdAt'] as String,
      status: json['status'] as String? ?? 'pending',
      failReason: json['failReason'] as String?,
      ownerUserId: json['ownerUserId'] as String?,
    );
  }

  QueuedMutation copyWith({
    String? status,
    String? failReason,
    bool clearFailReason = false,
    String? ownerUserId,
  }) {
    return QueuedMutation(
      clientMutationId: clientMutationId,
      kind: kind,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      failReason: clearFailReason ? null : (failReason ?? this.failReason),
      ownerUserId: ownerUserId ?? this.ownerUserId,
    );
  }
}

class OfflineQueue {
  static const _boxName = 'teriyascore_offline_queue';
  static const _metaBox = 'teriyascore_sync_meta';
  late Box<String> _box;
  late Box<String> _meta;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _meta = await Hive.openBox<String>(_metaBox);
  }

  List<QueuedMutation> list({bool pendingOnly = false, String? ownerUserId}) {
    var all = _box.values
        .map((e) => QueuedMutation.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    if (ownerUserId != null) {
      all = all.where((m) => m.ownerUserId == ownerUserId).toList();
    }
    if (pendingOnly) {
      return all.where((m) => m.status == 'pending').toList();
    }
    return all;
  }

  int get count => list(pendingOnly: true).length;

  int countFor(String? ownerUserId) {
    if (ownerUserId == null || ownerUserId.isEmpty) return 0;
    return list(pendingOnly: true, ownerUserId: ownerUserId).length;
  }

  /// Anciennes mutations sans propriétaire → compte actuellement connecté.
  Future<void> adoptOrphans(String userId) async {
    for (final key in _box.keys.toList()) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final m = QueuedMutation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (m.ownerUserId == null || m.ownerUserId!.isEmpty) {
        await _box.put(key, jsonEncode(m.copyWith(ownerUserId: userId).toJson()));
      }
    }
  }

  Future<void> clearForOwner(String userId) async {
    final ids = list(ownerUserId: userId).map((m) => m.clientMutationId).toList();
    await clearAccepted(ids);
  }

  Future<void> enqueue(QueuedMutation mutation) async {
    await _box.put(mutation.clientMutationId, jsonEncode(mutation.toJson()));
  }

  Future<void> clearAccepted(List<String> ids) async {
    for (final id in ids) {
      await _box.delete(id);
    }
  }

  Future<void> markFailed(String id, String reason) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final m = QueuedMutation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _box.put(
      id,
      jsonEncode(m.copyWith(status: 'failed', failReason: reason).toJson()),
    );
  }

  /// Remet une mutation rejetée en attente pour un nouvel essai.
  Future<void> retryFailed(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final m = QueuedMutation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (m.status != 'failed') return;
    await _box.put(
      id,
      jsonEncode(
        m.copyWith(status: 'pending', clearFailReason: true).toJson(),
      ),
    );
  }

  Future<void> discard(String id) async {
    await _box.delete(id);
  }

  int get failedCount =>
      list().where((m) => m.status == 'failed').length;

  String? get lastPullSince => _meta.get('lastPullSince');

  Future<void> setLastPullSince(String iso) async {
    await _meta.put('lastPullSince', iso);
  }

  Future<void> clearMeta() async {
    await _meta.clear();
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _meta.clear();
  }

  static String newId() => const Uuid().v4();
}
