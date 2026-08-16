import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_widgets.dart';
import '../agent/agent_store.dart';
import '../auth/app_lock.dart';
import '../auth/auth_provider.dart';
import '../notifications/notifications_data.dart';
import '../sync/sync_service.dart';

/// Préférences UX, sync, sécurité — séparé du profil identité.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late String theme;
  bool saving = false;
  String? message;
  String? error;
  int queueRevision = 0;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(uxPrefsProvider);
    theme = prefs.theme;
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
      message = null;
    });
    try {
      await ref.read(uxPrefsProvider.notifier).persist(
            language: 'fr',
            theme: theme,
          );
      if (!mounted) return;
      final t = ref.read(tsStringsProvider);
      setState(() => message = t('settingsSaved'));
    } catch (_) {
      if (!mounted) return;
      setState(() => error = ref.read(tsStringsProvider)('settingsSaveError'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final _ = queueRevision;
    final t = ref.watch(tsStringsProvider);
    final lock = ref.watch(appLockProvider);
    final pending = ref.watch(syncPendingProvider);
    final syncErr = ref.watch(syncErrorProvider);
    final queue = ref.read(offlineQueueProvider);
    final uid = ref.watch(authProvider.select((s) => s.user?.id));
    final failedItems = queue
        .list(ownerUserId: uid)
        .where((m) => m.status == 'failed')
        .toList();
    final failed = failedItems.length;
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('settings')),
        leading: tsBackButton(context, fallbackLocation: '/app/profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('settingsAppearance'),
            style: TextStyle(
              color: TsTokens.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: TsTokens.elevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TsTokens.brand),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('theme'),
                  style: TextStyle(
                    color: TsTokens.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                TsSegmented(
                  value: theme,
                  onChanged: (v) {
                    setState(() => theme = v);
                    ref.read(uxPrefsProvider.notifier).setThemeLocal(v);
                  },
                  options: [
                    ('light', t('themeLight')),
                    ('dark', t('themeDark')),
                    ('system', t('themeSystem')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('settingsSecurity'),
            style: TextStyle(
              color: TsTokens.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (lock.biometricAvailable) ...[
            const SizedBox(height: 12),
            Text(t('lock'), style: TextStyle(color: TsTokens.textMute)),
            const SizedBox(height: 8),
            TsSegmented(
              value: lock.biometricEnabled ? 'oui' : 'non',
              onChanged: (v) => ref
                  .read(appLockProvider.notifier)
                  .setBiometricEnabled(v == 'oui'),
              options: [('oui', t('yes')), ('non', t('no'))],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              t('lockUnavailable'),
              style: TextStyle(color: TsTokens.textMute, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            t('settingsTools'),
            style: TextStyle(
              color: TsTokens.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(t('notifications')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TsTokens.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/app/notifications'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              pending > 0
                  ? '${t('offlineQueue')} · ${t.format('offlinePending', {'n': '$pending'})}'
                  : failed > 0
                      ? '${t('offlineQueue')} · ${t.format('offlineFailed', {'n': '$failed'})}'
                      : '${t('offlineQueue')} · ${t('offlineUpToDate')}',
            ),
            subtitle: syncErr != null
                ? Text(syncErr, style: const TextStyle(color: TsTokens.danger))
                : Text(
                    t('offlineQueueHint'),
                    style: TextStyle(color: TsTokens.textMute, fontSize: 12),
                  ),
            trailing: pending > 0 || failed > 0
                ? TextButton(
                    onPressed: () async {
                      await ref.read(syncServiceProvider).acknowledgeLocal();
                      await ref
                          .read(agentDossierStoreProvider)
                          .refreshSyncedFlags();
                      setState(() => queueRevision++);
                    },
                    child: Text(t('retrySync')),
                  )
                : null,
          ),
          if (failedItems.isNotEmpty)
            ...failedItems.map(
              (m) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(m.kind, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  m.failReason ?? t('syncFailed'),
                  style: const TextStyle(color: TsTokens.danger, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: t('retrySync'),
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () async {
                        await ref
                            .read(offlineQueueProvider)
                            .retryFailed(m.clientMutationId);
                        await ref.read(syncServiceProvider).acknowledgeLocal();
                        await ref
                            .read(agentDossierStoreProvider)
                            .refreshSyncedFlags();
                        setState(() => queueRevision++);
                      },
                    ),
                    IconButton(
                      tooltip: t('discardSync'),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        await ref
                            .read(offlineQueueProvider)
                            .discard(m.clientMutationId);
                        await ref.read(syncServiceProvider).refreshCount();
                        setState(() => queueRevision++);
                      },
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: TsTokens.brand),
            title: Text(t('aboutHelp')),
            subtitle: Text(t('aboutHelpHint')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/app/aide'),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: const TextStyle(color: TsTokens.ok)),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: TsTokens.danger)),
          ],
          const SizedBox(height: 16),
          TsPrimaryButton(
            label: t('save'),
            loading: saving,
            onPressed: saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
