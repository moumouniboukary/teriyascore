import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/client.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/offline/local_cache.dart';
import '../../core/offline/queue.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_numeric_keypad.dart';
import '../../core/widgets/ts_widgets.dart';
import '../sync/sync_service.dart';
import 'ledger_data.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  String type = 'vente';
  String canal = 'especes';
  String natureStock = 'entree';
  DateTime dueDate = DateTime.now().add(const Duration(days: 7));
  final amountCtrl = TextEditingController(text: '2500');
  final clientCtrl = TextEditingController();
  final productCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  String? selectedClientId;
  bool loading = false;
  bool done = false;
  bool savedOffline = false;
  String? error;

  @override
  void dispose() {
    amountCtrl.dispose();
    clientCtrl.dispose();
    productCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  void _setType(String v) {
    setState(() => type = v);
  }

  /// Dialogue de création d'un nouveau client → sélectionné automatiquement.
  Future<void> _createClient() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final created = await showDialog<ClientInfo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final nom = nameCtrl.text.trim();
              if (nom.isEmpty) return;
              try {
                final client = await ref
                    .read(clientsRepositoryProvider)
                    .create(nom: nom, telephone: phoneCtrl.text);
                if (ctx.mounted) Navigator.of(ctx).pop(client);
              } on ApiException catch (e) {
                if (e.isOffline || e.isServerError) {
                  final mutationId = OfflineQueue.newId();
                  final createdAt = DateTime.now().toUtc().toIso8601String();
                  final localId = 'local-$mutationId';
                  await ref.read(offlineQueueProvider).enqueue(
                        QueuedMutation(
                          clientMutationId: mutationId,
                          kind: 'create_client',
                          payload: {
                            'nom': nom,
                            if (phoneCtrl.text.trim().isNotEmpty)
                              'telephone': phoneCtrl.text.trim(),
                            'clientMutationId': mutationId,
                          },
                          createdAt: createdAt,
                        ),
                      );
                  await ref.read(localCacheProvider).mergeListById(
                        LocalCacheKeys.clients,
                        [
                          {
                            'id': localId,
                            'nom': nom,
                            if (phoneCtrl.text.trim().isNotEmpty)
                              'telephone': phoneCtrl.text.trim(),
                            'pendingSync': true,
                          },
                        ],
                      );
                  await ref.read(syncServiceProvider).refreshCount();
                  ref.read(ledgerRevisionProvider.notifier).state++;
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(
                      ClientInfo(
                        id: localId,
                        nom: nom,
                        telephone: phoneCtrl.text.trim(),
                      ),
                    );
                  }
                } else if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (created != null) {
      if (created.id.isNotEmpty) {
        ref.read(ledgerRevisionProvider.notifier).state++;
        setState(() {
          selectedClientId = created.id;
          clientCtrl.text = created.nom;
        });
      } else {
        // Client créé hors ligne — créance via clientName.
        setState(() {
          selectedClientId = null;
          clientCtrl.text = created.nom;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\s'), '')) ?? 0;
    final mutationId = OfflineQueue.newId();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'type': type,
      'amountFcfa': amount,
      if (type == 'vente') 'label': 'Vente',
      if (type == 'stock') ...{
        'label': productCtrl.text.trim().isEmpty
            ? 'Stock'
            : productCtrl.text.trim(),
        'natureStock': natureStock,
        'productName': productCtrl.text.trim().isEmpty
            ? 'Article'
            : productCtrl.text.trim(),
        'quantiteStock':
            int.tryParse(qtyCtrl.text.replaceAll(RegExp(r'\s'), '')) ?? 1,
      },
      if (type == 'depense') 'label': 'Dépense',
      if (type == 'creance') ...{
        if (selectedClientId != null &&
            !selectedClientId!.startsWith('local-'))
          'clientId': selectedClientId
        else
          'clientName':
              clientCtrl.text.trim().isEmpty ? 'Client' : clientCtrl.text.trim(),
        'dueAt': dueDate.toUtc().toIso8601String(),
      },
      if (type == 'vente' || type == 'depense') 'canal': canal,
      'clientMutationId': mutationId,
      'createdAt': createdAt,
    };

    try {
      await ref.read(apiClientProvider).post('/operations', data: payload);
      // Notifie les autres écrans (accueil, cahier, créances) de se recharger.
      ref.read(ledgerRevisionProvider.notifier).state++;
      setState(() {
        savedOffline = false;
        done = true;
      });
    } on ApiException catch (e) {
      if (e.isOffline || e.isServerError) {
        await ref.read(offlineQueueProvider).enqueue(
              QueuedMutation(
                clientMutationId: mutationId,
                kind: 'create_operation',
                payload: payload,
                createdAt: createdAt,
              ),
            );
        // Cache optimiste : l'opération apparaît tout de suite dans le cahier.
        final optimistic = <String, dynamic>{
          'id': mutationId,
          'type': type,
          'amountFcfa': amount,
          'montantFcfa': amount,
          'label': payload['label'] ?? type,
          'createdAt': createdAt,
          'dateOperation': createdAt,
          'pendingSync': true,
          if (type == 'creance') ...{
            'clientName': payload['clientName'],
            'dueAt': payload['dueAt'],
            'statutCreance': 'ouverte',
          },
        };
        await ref.read(localCacheProvider).mergeListById(
              LocalCacheKeys.operations,
              [optimistic],
            );
        if (type == 'creance' &&
            selectedClientId == null &&
            clientCtrl.text.trim().isNotEmpty) {
          final clientId = 'local-${mutationId.substring(0, 8)}';
          await ref.read(localCacheProvider).mergeListById(
                LocalCacheKeys.clients,
                [
                  {
                    'id': clientId,
                    'nom': clientCtrl.text.trim(),
                    if (payload['telephone'] != null)
                      'telephone': payload['telephone'],
                  },
                ],
              );
        }
        await ref.read(syncServiceProvider).refreshCount();
        ref.read(ledgerRevisionProvider.notifier).state++;
        setState(() {
          savedOffline = true;
          done = true;
        });
      } else {
        setState(() => error = e.message);
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Scaffold(
        appBar: AppBar(
          leading: tsBackButton(context, fallbackLocation: '/app'),
          title: const Text('Enregistré'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 72, color: TsTokens.ok),
              const SizedBox(height: 12),
              Text(
                savedOffline
                    ? 'Enregistré hors ligne — synchronisation au retour du réseau'
                    : 'Synchronisé',
                style: TextStyle(color: TsTokens.textMute),
              ),
              const Spacer(),
              TsPrimaryButton(label: 'Accueil', onPressed: () => context.go('/app')),
              TextButton(
                onPressed: () => setState(() {
                  done = false;
                  amountCtrl.clear();
                }),
                child: const Text('Nouvelle opération'),
              ),
            ],
          ),
        ),
      );
    }

    final t = ref.watch(tsStringsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: tsBackButton(context, fallbackLocation: '/app'),
        title: Text(t('record')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TsSegmented(
              value: type,
              onChanged: _setType,
              options: [
                ('vente', t('sale')),
                ('stock', t('stock')),
                ('creance', t('receivable')),
                ('depense', t('expense')),
              ],
            ),
          if (type == 'creance') ...[
            const SizedBox(height: 16),
            _ClientField(
              selectedClientId: selectedClientId,
              fallbackCtrl: clientCtrl,
              label: t('client'),
              onSelected: (id) => setState(() => selectedClientId = id),
              onCreate: _createClient,
            ),
            const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('dueDate')),
                subtitle: Text(
                  DateFormat.yMMMd('fr').format(dueDate),
                  style: TextStyle(color: TsTokens.textMute),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setState(() => dueDate = picked);
                },
              ),
          ],
          if (type == 'stock') ...[
            const SizedBox(height: 16),
            TsSegmented(
              value: natureStock,
              onChanged: (v) => setState(() => natureStock = v),
              options: [
                ('entree', t('stockIn')),
                ('sortie', t('stockOut')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: productCtrl,
              decoration: InputDecoration(labelText: t('articleName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: t('quantity')),
            ),
          ],
          if (type == 'vente' || type == 'depense') ...[
            const SizedBox(height: 16),
            Text(t('cash'), style: TextStyle(color: TsTokens.textMute)),
            const SizedBox(height: 8),
            TsSegmented(
              value: canal,
              onChanged: (v) => setState(() => canal = v),
              options: [
                ('especes', t('cash')),
                ('mobile_money', t('mobileMoney')),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TsKeypadAmountField(
            controller: amountCtrl,
            label: t('amount'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: TsTokens.danger)),
          ],
          const SizedBox(height: 20),
          TsPrimaryButton(
            label: t('confirm'),
            loading: loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de client pour une créance : liste déroulante des clients
/// existants + option « Nouveau client ». Repli sur un champ texte libre
/// si l'API est injoignable (mode hors-ligne).
class _ClientField extends ConsumerWidget {
  const _ClientField({
    required this.selectedClientId,
    required this.fallbackCtrl,
    required this.label,
    required this.onSelected,
    required this.onCreate,
  });

  final String? selectedClientId;
  final TextEditingController fallbackCtrl;
  final String label;
  final ValueChanged<String?> onSelected;
  final Future<void> Function() onCreate;

  static const _newValue = '__new__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    return clientsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => TextField(
        controller: fallbackCtrl,
        decoration: InputDecoration(
          labelText: label,
          helperText: ref.watch(tsStringsProvider)('offlineCache'),
        ),
      ),
      data: (clients) {
        final t = ref.watch(tsStringsProvider);
        final valid = clients.any((c) => c.id == selectedClientId)
            ? selectedClientId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: valid,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          hint: Text(t('chooseClient')),
          items: [
            ...clients.map(
              (c) => DropdownMenuItem(value: c.id, child: Text(c.nom)),
            ),
            DropdownMenuItem(
              value: _newValue,
              child: Row(
                children: [
                  const Icon(Icons.add, size: 18),
                  const SizedBox(width: 8),
                  Text(t('newClient')),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v == _newValue) {
              onCreate();
            } else {
              onSelected(v);
            }
          },
        );
      },
    );
  }
}

class VentesPage extends ConsumerStatefulWidget {
  const VentesPage({super.key});

  @override
  ConsumerState<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends ConsumerState<VentesPage> {
  List<Map<String, dynamic>> ops = [];
  bool fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(apiClientProvider).get<List>(
            '/operations?type=vente',
            parse: (d) => d as List,
          );
      final mapped =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await ref.read(localCacheProvider).mergeListById(
            LocalCacheKeys.operations,
            mapped,
          );
      if (!mounted) return;
      setState(() {
        ops = mapped;
        fromCache = false;
      });
    } catch (_) {
      final cached = ref
          .read(localCacheProvider)
          .getList(LocalCacheKeys.operations)
          .where((o) => o['type']?.toString() == 'vente')
          .toList();
      if (!mounted) return;
      setState(() {
        ops = cached;
        fromCache = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(ledgerRevisionProvider, (_, _) => _load());
    final fmt = NumberFormat.decimalPattern('fr');
    final t = ref.watch(tsStringsProvider);
    final total = ops.fold<int>(0, (s, o) => s + (o['amountFcfa'] as int? ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(t('ledger')),
        actions: [
          IconButton(
              onPressed: () => context.push('/app/enregistrer'),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  ops.isEmpty ? t('offlineCanRecord') : t('offlineCache'),
                  style: TextStyle(color: TsTokens.textMute, fontSize: 13),
                ),
              ),
            Text(
              '${fmt.format(total)} FCFA',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: TsTokens.brandSoft,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (ops.isEmpty) ...[
              Text(t('noSales'), style: TextStyle(color: TsTokens.textMute)),
              const SizedBox(height: 12),
              TsPrimaryButton(
                  label: t('recordSale'),
                  onPressed: () => context.push('/app/enregistrer'),
                ),
            ] else
              ...ops.map(
                (op) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(op['label']?.toString() ?? t('sale')),
                  subtitle: Text(
                    op['dateOperation']?.toString() ??
                        op['createdAt']?.toString() ??
                        '',
                    style: TextStyle(color: TsTokens.textMute, fontSize: 12),
                  ),
                  trailing: Text(
                    '+${fmt.format(op['amountFcfa'] ?? 0)}',
                    style: const TextStyle(
                      color: TsTokens.ok,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DettesPage extends ConsumerStatefulWidget {
  const DettesPage({super.key});

  @override
  ConsumerState<DettesPage> createState() => _DettesPageState();
}

class _DettesPageState extends ConsumerState<DettesPage> {
  List<Map<String, dynamic>> ops = [];
  String? busyId;
  bool fromCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(apiClientProvider).get<List>(
            '/operations?type=creance',
            parse: (d) => d as List,
          );
      final mapped = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((o) {
            final s = o['statutCreance']?.toString();
            return s == null || s == 'ouverte' || s == 'en_retard';
          })
          .toList();
      await ref.read(localCacheProvider).putList(
            LocalCacheKeys.operations,
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
      if (!mounted) return;
      setState(() {
        ops = mapped;
        fromCache = false;
      });
    } catch (_) {
      final cached = ref
          .read(localCacheProvider)
          .getList(LocalCacheKeys.operations)
          .where((o) {
            if (o['type']?.toString() != 'creance') return false;
            final s = o['statutCreance']?.toString();
            return s == null || s == 'ouverte' || s == 'en_retard';
          })
          .toList();
      if (!mounted) return;
      setState(() {
        ops = cached;
        fromCache = true;
      });
    }
  }

  int _remaining(Map<String, dynamic> op) {
    final total = op['remainingFcfa'] as int? ??
        ((op['amountFcfa'] as int? ?? 0) -
            (op['montantRegleFcfa'] as int? ??
                op['amountSettledFcfa'] as int? ??
                0));
    return total < 0 ? 0 : total;
  }

  Future<void> _settle(String id, {int? amountFcfa}) async {
    setState(() => busyId = id);
    final mutationId = OfflineQueue.newId();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'operationId': id,
      if (amountFcfa != null) 'amountFcfa': amountFcfa,
    };
    try {
      await ref.read(apiClientProvider).post(
            '/operations/$id/settle',
            data: {if (amountFcfa != null) 'amountFcfa': amountFcfa},
          );
      ref.read(ledgerRevisionProvider.notifier).state++;
      await _load();
    } on ApiException catch (e) {
      if (e.isOffline || e.isServerError) {
        await ref.read(offlineQueueProvider).enqueue(
              QueuedMutation(
                clientMutationId: mutationId,
                kind: 'settle_creance',
                payload: payload,
                createdAt: createdAt,
              ),
            );
        await ref.read(syncServiceProvider).refreshCount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(tsStringsProvider)('savedOffline'))),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _settlePartial(Map<String, dynamic> op) async {
    final id = op['id']?.toString() ?? '';
    final reste = _remaining(op);
    final ctrl = TextEditingController(text: '$reste');
    final t = ref.read(tsStringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('settlePartial')),
        content: SingleChildScrollView(
          child: TsKeypadAmountField(controller: ctrl, label: t('amount')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('deny')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = int.tryParse(ctrl.text.replaceAll(RegExp(r'\s'), '')) ?? 0;
    if (amount <= 0) return;
    await _settle(id, amountFcfa: amount);
  }

  Future<void> _remind(String id) async {
    setState(() => busyId = id);
    final t = ref.read(tsStringsProvider);
    try {
      await ref.read(apiClientProvider).post('/operations/$id/remind');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('reminderSent'))),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _changeDue(Map<String, dynamic> op) async {
    final id = op['id']?.toString() ?? '';
    final current = DateTime.tryParse(op['dueAt']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(DateTime.now()) ? DateTime.now() : current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => busyId = id);
    try {
      await ref.read(apiClientProvider).patch(
            '/operations/$id/due',
            data: {'dueAt': picked.toUtc().toIso8601String()},
          );
      ref.read(ledgerRevisionProvider.notifier).state++;
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(ledgerRevisionProvider, (_, _) => _load());
    final fmt = NumberFormat.decimalPattern('fr');
    final t = ref.watch(tsStringsProvider);
    final total = ops.fold<int>(0, (s, o) => s + _remaining(o));
    return Scaffold(
      appBar: AppBar(
        title: Text(t('debts')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${t('toCollect')} · ${fmt.format(total)} FCFA',
              style: TextStyle(color: TsTokens.warn, fontWeight: FontWeight.w700),
            ),
            if (fromCache)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t('offlineCache'),
                  style: TextStyle(color: TsTokens.textMute, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (ops.isEmpty) ...[
              Text(
                fromCache ? t('offlineCanRecord') : t('noOpenDebts'),
                style: TextStyle(color: TsTokens.textMute),
              ),
              const SizedBox(height: 12),
              TsPrimaryButton(
                label: t('recordDebt'),
                onPressed: () => context.push('/app/enregistrer'),
              ),
            ] else
              ...ops.map((op) {
                final id = op['id']?.toString() ?? '';
                final reste = _remaining(op);
                final overdue = op['statutCreance']?.toString() == 'en_retard';
                final due = op['dueAt']?.toString();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                op['clientName']?.toString() ?? t('client'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              '${fmt.format(reste)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          overdue
                              ? t('overdue')
                              : (due != null
                                  ? '${t('dueDate')} · ${due.substring(0, 10)}'
                                  : t('openDebt')),
                          style: TextStyle(
                            color: overdue ? TsTokens.danger : TsTokens.textMute,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed:
                                    busyId == id ? null : () => _settle(id),
                                child: Text(
                                  busyId == id ? '…' : t('payDebt'),
                                ),
                              ),
                              TextButton(
                                onPressed: busyId == id
                                    ? null
                                    : () => _settlePartial(op),
                                child: Text(t('settlePartial')),
                              ),
                              TextButton(
                                onPressed:
                                    busyId == id ? null : () => _remind(id),
                                child: Text(t('remind')),
                              ),
                              TextButton(
                                onPressed: busyId == id
                                    ? null
                                    : () => _changeDue(op),
                                child: Text(t('dueDate')),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
