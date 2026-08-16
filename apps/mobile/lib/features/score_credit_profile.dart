import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/client.dart';
import '../../core/offline/local_cache.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/offline/queue.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_speak_button.dart';
import '../../core/widgets/ts_widgets.dart';
import 'auth/auth_provider.dart';
import 'agent/agent_store.dart';
import 'sync/sync_service.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController nameCtrl;
  late TextEditingController coopCtrl;
  late TextEditingController idNumberCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController birthDateCtrl;
  String idType = 'cni';
  String kycStatut = 'non_verifie';
  bool shareImf = false;
  bool consentAnonymized = true;
  bool consentMarketing = false;
  bool saving = false;
  String? message;
  String? error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    nameCtrl = TextEditingController(text: user?.displayName ?? '');
    coopCtrl = TextEditingController(text: ref.read(agentCoopProvider));
    idNumberCtrl = TextEditingController();
    addressCtrl = TextEditingController();
    birthDateCtrl = TextEditingController();
    _loadConsents();
    _loadKyc();
  }

  Future<void> _loadKyc() async {
    void apply(Map<String, dynamic> me) {
      final rawBirth = me['dateNaissance']?.toString();
      String birth = '';
      if (rawBirth != null && rawBirth.length >= 10) {
        birth = rawBirth.substring(0, 10);
      }
      setState(() {
        kycStatut = me['kycStatut']?.toString() ?? 'non_verifie';
        idType = me['pieceIdentiteType']?.toString() ?? 'cni';
        idNumberCtrl.text = me['pieceIdentiteNumero']?.toString() ?? '';
        addressCtrl.text = me['adresse']?.toString() ?? '';
        birthDateCtrl.text = birth;
      });
    }

    try {
      final me = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '/me',
            parse: (d) => Map<String, dynamic>.from(d as Map),
          );
      if (!mounted) return;
      await ref.read(localCacheProvider).putMap(LocalCacheKeys.profile, me);
      apply(me);
    } catch (_) {
      final cached = ref.read(localCacheProvider).getMap(LocalCacheKeys.profile);
      if (cached != null && mounted) apply(cached);
    }
  }

  Future<void> _loadConsents() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/me/consents',
            parse: (d) => Map<String, dynamic>.from(d as Map),
          );
      final items = (res['items'] as List?) ?? [];
      bool? imf;
      bool? anon;
      bool? marketing;
      for (final raw in items) {
        final i = Map<String, dynamic>.from(raw as Map);
        final type = i['type']?.toString();
        final accorde = i['accorde'] == true;
        if (type == 'partage_imf') imf = accorde;
        if (type == 'anonymisation_recherche') anon = accorde;
        if (type == 'marketing_partenaires') marketing = accorde;
      }
      if (!mounted) return;
      setState(() {
        if (imf != null) shareImf = imf;
        if (anon != null) consentAnonymized = anon;
        if (marketing != null) consentMarketing = marketing;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    coopCtrl.dispose();
    idNumberCtrl.dispose();
    addressCtrl.dispose();
    birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
      message = null;
    });
    final displayName = nameCtrl.text.trim();
    final idNumber = idNumberCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final birth = birthDateCtrl.text.trim();
    await ref.read(agentCoopProvider.notifier).setName(coopCtrl.text);
    final profilePayload = <String, dynamic>{
      'displayName': displayName,
      if (idNumber.isNotEmpty) 'pieceIdentiteType': idType,
      if (idNumber.isNotEmpty) 'pieceIdentiteNumero': idNumber,
      if (address.isNotEmpty) 'adresse': address,
      if (birth.length >= 10) 'dateNaissance': birth.substring(0, 10),
    };
    final consentsPayload = {
      'consentCreditPartners': shareImf,
      'consentAnonymized': consentAnonymized,
      'consentMarketing': consentMarketing,
    };
    try {
      final me = await ref
          .read(apiClientProvider)
          .patch<Map<String, dynamic>>(
            '/me',
            data: profilePayload,
            parse: (d) => Map<String, dynamic>.from(d as Map),
          );
      final user = ref.read(authProvider).user!;
      ref
          .read(authProvider.notifier)
          .setUser(
            user.copyWith(
              displayName: me['displayName'] as String? ?? displayName,
              onboardingCompleted: me['onboardingCompleted'] == true,
            ),
          );
      await ref
          .read(apiClientProvider)
          .put('/me/consents', data: consentsPayload);
      setState(() {
        message = 'Profil enregistré';
        if (me['kycStatut'] != null) {
          kycStatut = me['kycStatut'].toString();
        }
      });
      await ref.read(localCacheProvider).putMap(LocalCacheKeys.profile, me);
    } on ApiException catch (e) {
      if (e.isOffline || e.isServerError) {
        final createdAt = DateTime.now().toUtc().toIso8601String();
        final queue = ref.read(offlineQueueProvider);
        await queue.enqueue(
          QueuedMutation(
            clientMutationId: OfflineQueue.newId(),
            kind: 'update_profile',
            payload: profilePayload,
            createdAt: createdAt,
          ),
        );
        await queue.enqueue(
          QueuedMutation(
            clientMutationId: OfflineQueue.newId(),
            kind: 'update_consents',
            payload: consentsPayload,
            createdAt: createdAt,
          ),
        );
        // Brouillon KYC / profil lisible hors ligne jusqu'à la sync.
        final existing =
            ref.read(localCacheProvider).getMap(LocalCacheKeys.profile) ??
                <String, dynamic>{};
        await ref.read(localCacheProvider).putMap(LocalCacheKeys.profile, {
          ...existing,
          'displayName': displayName,
          if (idNumber.isNotEmpty) 'pieceIdentiteType': idType,
          if (idNumber.isNotEmpty) 'pieceIdentiteNumero': idNumber,
          if (address.isNotEmpty) 'adresse': address,
          if (birth.length >= 10) 'dateNaissance': birth.substring(0, 10),
          'kycStatut': kycStatut == 'non_verifie' ? 'en_cours' : kycStatut,
          'pendingSync': true,
        });
        await ref.read(syncServiceProvider).refreshCount();
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref
              .read(authProvider.notifier)
              .setUser(user.copyWith(displayName: displayName));
        }
        setState(() => message = 'Enregistré hors ligne — sync au retour réseau');
      } else {
        setState(() => error = e.message);
      }
    } finally {
      setState(() => saving = false);
    }
  }

  Future<void> _exportData() async {
    setState(() {
      error = null;
      message = null;
    });
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            '/me/export',
            parse: (d) => Map<String, dynamic>.from(d as Map),
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export de mes données'),
          content: Text(
            'Export généré le ${data['exportedAt'] ?? '—'}.\n\n'
            'Les données du compte sont disponibles via l’API '
            'GET /me/export (JSON portable RGPD).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() => message = 'Export prêt');
    } on ApiException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _deleteAccount() async {
    final pinCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Action irréversible : le compte agent et les données '
              'associées seront effacés.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirmer avec votre PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TsTokens.danger),
            onPressed: () {
              if (pinCtrl.text.length == 4) Navigator.of(ctx).pop(true);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).delete(
            '/me',
            data: {'pin': pinCtrl.text, 'confirm': true},
          );
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      setState(() => error = e.message);
    }
  }

  String _kycLabel(TsStrings t, String statut) {
    switch (statut) {
      case 'en_cours':
        return t('kycPending');
      case 'verifie':
        return t('kycVerified');
      case 'refuse':
        return t('kycRejected');
      default:
        return t('kycUnverified');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final t = ref.watch(tsStringsProvider);

    return TsVoiceOnOpen(
      labelKey: 'profile',
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('profile')),
          actions: [
            IconButton(
              tooltip: t('settings'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/app/parametres'),
            ),
            const TsSpeakButton(labelKey: 'profile', alwaysShow: true),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: TsTokens.brand,
              child: Text(
                (user?.displayName ?? 'N').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  color: TsTokens.onBrand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.phone ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: TsTokens.textMute),
            ),
            const SizedBox(height: 16),
            Material(
              color: TsTokens.elevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: TsTokens.brand.withValues(alpha: 0.45)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: TsTokens.brand,
                    ),
                    title: Text(t('settings')),
                    subtitle: Text(
                      t('settingsAppearance'),
                      style: TextStyle(
                        color: TsTokens.textMute,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/parametres'),
                  ),
                  Divider(height: 1, color: TsTokens.line),
                  ListTile(
                    leading: const Icon(
                      Icons.help_outline,
                      color: TsTokens.brand,
                    ),
                    title: Text(t('aboutHelp')),
                    subtitle: Text(
                      t('aboutHelpHint'),
                      style: TextStyle(
                        color: TsTokens.textMute,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/app/aide'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('profileIdentity'),
              style: TextStyle(
                color: TsTokens.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: t('displayName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coopCtrl,
              decoration: InputDecoration(labelText: t('cooperative')),
            ),
            const SizedBox(height: 16),
            Text(
              t('kycSection'),
              style: TextStyle(
                color: TsTokens.text,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('kycHint'),
              style: TextStyle(color: TsTokens.textMute, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '${t('kycStatus')} : ${_kycLabel(t, kycStatut)}',
              style: TextStyle(color: TsTokens.brand, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(t('idType'), style: TextStyle(color: TsTokens.textMute)),
            const SizedBox(height: 8),
            TsSegmented(
              value: idType,
              onChanged: (v) => setState(() => idType = v),
              options: [
                ('cni', t('idCni')),
                ('passport', t('idPassport')),
                ('consulaire', t('idConsular')),
                ('autre', t('idOther')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idNumberCtrl,
              decoration: InputDecoration(labelText: t('idNumber')),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: birthDateCtrl,
              decoration: InputDecoration(
                labelText: t('birthDate'),
                hintText: 'AAAA-MM-JJ',
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: InputDecoration(labelText: t('address')),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(t('shareImf'), style: TextStyle(color: TsTokens.textMute)),
            TsSegmented(
              value: shareImf ? 'ok' : 'no',
              onChanged: (v) => setState(() => shareImf = v == 'ok'),
              options: [('ok', t('allow')), ('no', t('deny'))],
            ),
            const SizedBox(height: 12),
            Text(t('consentAnonymized'), style: TextStyle(color: TsTokens.textMute)),
            TsSegmented(
              value: consentAnonymized ? 'ok' : 'no',
              onChanged: (v) => setState(() => consentAnonymized = v == 'ok'),
              options: [('ok', t('allow')), ('no', t('deny'))],
            ),
            const SizedBox(height: 12),
            Text(t('consentMarketing'), style: TextStyle(color: TsTokens.textMute)),
            TsSegmented(
              value: consentMarketing ? 'ok' : 'no',
              onChanged: (v) => setState(() => consentMarketing = v == 'ok'),
              options: [('ok', t('allow')), ('no', t('deny'))],
            ),
            if (message != null)
              Text(message!, style: const TextStyle(color: TsTokens.ok)),
            if (error != null)
              Text(error!, style: const TextStyle(color: TsTokens.danger)),
            const SizedBox(height: 12),
            TsPrimaryButton(label: t('save'), loading: saving, onPressed: _save),
            const SizedBox(height: 20),
            _PrivacyActions(
              onExport: _exportData,
              onDelete: _deleteAccount,
              onLogout: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              logoutLabel: t('logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyActions extends StatelessWidget {
  const _PrivacyActions({
    required this.onExport,
    required this.onDelete,
    required this.onLogout,
    required this.logoutLabel,
  });

  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onLogout;
  final String logoutLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: TsTokens.elevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TsTokens.line),
            boxShadow: TsTokens.isDark
                ? null
                : [
                    BoxShadow(
                      color: TsTokens.text.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PrivacyActionTile(
                icon: Icons.download_outlined,
                iconColor: TsTokens.brand,
                iconBg: TsTokens.brand.withValues(alpha: 0.12),
                title: 'Exporter mes données',
                subtitle: 'Droit d’accès RGPD',
                onTap: onExport,
              ),
              Divider(height: 1, thickness: 1, color: TsTokens.line),
              _PrivacyActionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: TsTokens.danger,
                iconBg: TsTokens.danger.withValues(alpha: 0.12),
                title: 'Supprimer mon compte',
                titleColor: TsTokens.danger,
                subtitle: 'Droit à l’oubli — irréversible',
                onTap: onDelete,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: TsTokens.danger,
              backgroundColor: TsTokens.elevated,
              side: BorderSide(
                color: TsTokens.danger.withValues(alpha: 0.45),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
            child: Text(logoutLabel),
          ),
        ),
      ],
    );
  }
}

class _PrivacyActionTile extends StatelessWidget {
  const _PrivacyActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor ?? TsTokens.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: TsTokens.textMute,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: TsTokens.textMute.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
