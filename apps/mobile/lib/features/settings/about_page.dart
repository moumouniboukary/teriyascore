import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_widgets.dart';

/// À propos / Aide : explique le fonctionnement de TeriyaScore.
class AboutHelpPage extends ConsumerWidget {
  const AboutHelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tsStringsProvider);
    final support = TsTokens.supportPhone;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('aboutHelp')),
        leading: tsBackButton(context, fallbackLocation: '/app/parametres'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/branding/teriyascore-logo-mark.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.storefront,
                    size: 48,
                    color: TsTokens.brand,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TsTokens.appName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: TsTokens.brand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('aboutVersion'),
                      style: TextStyle(color: TsTokens.textMute, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t('aboutIntro'),
            style: TextStyle(color: TsTokens.textMute, height: 1.45),
          ),
          const SizedBox(height: 20),
          _HelpSection(
            icon: Icons.menu_book_outlined,
            title: t('helpWhatTitle'),
            body: t('helpWhatBody'),
          ),
          _HelpSection(
            icon: Icons.folder_outlined,
            title: t('helpAgentTitle'),
            body: t('helpAgentBody'),
          ),
          _HelpSection(
            icon: Icons.sync_outlined,
            title: t('helpSyncTitle'),
            body: t('helpSyncBody'),
          ),
          _HelpSection(
            icon: Icons.insights_outlined,
            title: t('helpScoreTitle'),
            body: t('helpScoreBody'),
          ),
          _HelpSection(
            icon: Icons.cloud_off_outlined,
            title: t('helpOfflineTitle'),
            body: t('helpOfflineBody'),
          ),
          _HelpSection(
            icon: Icons.accessibility_new_outlined,
            title: t('helpAccessTitle'),
            body: t('helpAccessBody'),
          ),
          _HelpSection(
            icon: Icons.lock_outline,
            title: t('helpSecurityTitle'),
            body: t('helpSecurityBody'),
          ),
          _HelpSection(
            icon: Icons.badge_outlined,
            title: t('helpProfileTitle'),
            body: t('helpProfileBody'),
          ),
          if (support != null && support.isNotEmpty) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent, color: TsTokens.brand),
              title: Text(t('helpSupport')),
              subtitle: Text(support),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t('aboutFooter'),
            style: TextStyle(
              color: TsTokens.textMute,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TsTokens.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: TsTokens.line),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, color: TsTokens.brand),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: TextStyle(
                    color: TsTokens.textMute,
                    height: 1.45,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
