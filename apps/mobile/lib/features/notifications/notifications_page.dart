import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/offline/local_cache.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_speak_button.dart';
import '../../core/widgets/ts_widgets.dart';
import 'notifications_data.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _iconFor(String type) {
    switch (type) {
      case 'credit_decision':
        return Icons.account_balance_wallet_outlined;
      case 'creance_retard':
        return Icons.warning_amber_outlined;
      case 'creance_relance':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _when(String iso) {
    if (iso.isEmpty) return '';
    try {
      return DateFormat(
        'dd MMM · HH:mm',
        'fr_FR',
      ).format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tsStringsProvider);
    final async = ref.watch(notificationsProvider);

    return TsVoiceOnOpen(
      labelKey: 'notifications',
      child: Scaffold(
      appBar: AppBar(
        leading: tsBackButton(context, fallbackLocation: '/app/parametres'),
        title: Text(t('notifications')),
        actions: [
          const TsSpeakButton(labelKey: 'notifications', alwaysShow: true),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsRepositoryProvider).markAllRead();
              } catch (_) {}
              ref.read(notificationsRevisionProvider.notifier).state++;
            },
            child: Text(t('markAllRead')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(notificationsRevisionProvider.notifier).state++;
          await ref.read(notificationsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TsOfflineEmpty(message: t('offlineNoData')),
          data: (items) {
            final hasCache = ref
                .read(localCacheProvider)
                .hasKey(LocalCacheKeys.notifications);
            if (items.isEmpty) {
              if (!hasCache) {
                return TsOfflineEmpty(message: t('offlineNoData'));
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: TsTokens.textMute,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('noNotifications'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TsTokens.textMute),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.lu
                        ? TsTokens.elevated.withValues(alpha: 0.5)
                        : TsTokens.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: n.lu ? TsTokens.line : TsTokens.brand,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconFor(n.type), color: TsTokens.brandSoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.titre,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.corps,
                              style: TextStyle(color: TsTokens.textMute),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _when(n.createdAt),
                              style: TextStyle(color: TsTokens.textMute,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!n.lu)
                        IconButton(
                          tooltip: t('markRead'),
                          icon: const Icon(Icons.check_circle_outline),
                          color: TsTokens.brandSoft,
                          onPressed: () async {
                            try {
                              await ref
                                  .read(notificationsRepositoryProvider)
                                  .markRead(n.id);
                            } catch (_) {}
                            ref.read(notificationsRevisionProvider.notifier).state++;
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
    );
  }
}
