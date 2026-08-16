import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agent/agent_store.dart';
import '../../features/auth/app_lock.dart';
import '../../features/sync/sync_service.dart';
import 'local_cache.dart';

/// Efface cache, file hors ligne et verrou — pour un compte vraiment neuf
/// sur le même téléphone.
Future<void> wipeLocalUserData(WidgetRef ref) async {
  await ref.read(localCacheProvider).clear();
  await ref.read(offlineQueueProvider).clearAll();
  await ref.read(appLockProvider.notifier).clear();
  ref.read(agentDossiersRevisionProvider.notifier).state++;
  ref.read(agentCoopProvider.notifier).reset();
  ref.read(syncPendingProvider.notifier).state = 0;
  ref.read(syncErrorProvider.notifier).state = null;
}
