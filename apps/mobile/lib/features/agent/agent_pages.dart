import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/locale_provider.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ts_speak_button.dart';
import '../auth/auth_provider.dart';
import '../sync/sync_service.dart';
import 'agent_store.dart';
import 'scorecard.dart';

Widget _agentCard({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TsTokens.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TsTokens.line),
      ),
      child: child,
    );

final _fcfa = NumberFormat.decimalPattern('fr');

String _money(num n) => '${_fcfa.format(n)} F';

enum _FormStep { client, profil, confiance, historique, capacite }

/// Liste des dossiers scoring agent (accueil).
class AgentDossiersPage extends ConsumerWidget {
  const AgentDossiersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(agentDossiersRevisionProvider);
    ref.watch(syncPendingProvider);
    final store = ref.read(agentDossierStoreProvider);
    final rows = store.list();
    final pending = ref.watch(syncPendingProvider);
    final t = ref.watch(tsStringsProvider);
    final iconMode = ref.watch(uxPrefsProvider).iconMode;
    final agentName = ref.watch(authProvider).user?.displayName.trim() ?? '';
    final coop = ref.watch(agentCoopProvider);
    final parts = agentName.split(' ').where((p) => p.isNotEmpty);
    final firstName = parts.isEmpty ? t('agentFallback') : parts.first;

    return TsVoiceOnOpen(
      labelKey: 'dossiersTerrain',
      child: Scaffold(
        backgroundColor: TsTokens.bg,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.format('helloName', {'name': firstName}),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: iconMode ? 18 : 16,
                ),
              ),
              Text(
                coop.isEmpty ? t('coopUnset') : coop,
                style: TextStyle(
                  color: TsTokens.textMute,
                  fontSize: iconMode ? 13 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: TsTokens.surface,
          actions: [
            if (pending > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Text(
                    '$pending ${t('pendingSends')}',
                    style: TextStyle(color: TsTokens.sand, fontSize: 12),
                  ),
                ),
              ),
            TsSpeakButton(
              text: rows.isEmpty
                  ? '${t('dossiersTerrain')}. ${t('agentEmpty')}'
                  : '${t('dossiersTerrain')}. ${rows.length} dossier(s).',
              alwaysShow: true,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            context.go('/app/nouveau');
          },
          backgroundColor: TsTokens.brand,
          foregroundColor: TsTokens.onBrand,
          icon: Icon(Icons.add, size: iconMode ? 30 : 24),
          label: Text(
            t('newDossierFull'),
            style: TextStyle(fontSize: iconMode ? 16 : 14),
          ),
        ),
        body: rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: iconMode ? 72 : 56,
                        color: TsTokens.textMute,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('agentEmpty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TsTokens.textMute,
                          height: 1.4,
                          fontSize: iconMode ? 16 : 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.go('/app/nouveau'),
                        icon: const Icon(Icons.add),
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(iconMode ? 56 : 48),
                        ),
                        label: Text(t('newDossierFull')),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await ref.read(syncServiceProvider).flush();
                  await store.refreshSyncedFlags();
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: iconMode ? 14 : 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final reco = r['recommendation']?.toString() ?? '';
                    final synced = r['synced'] == true;
                    final rawScore = (r['score'] as num?)?.toInt() ?? 0;
                    final shownScore =
                        rawScore <= 100 ? 300 + (rawScore * 5.5).round() : rawScore;
                    return Material(
                      color: TsTokens.elevated,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          context.push(
                            '/app/dossier/${r['id']}',
                            extra: r,
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.all(iconMode ? 18 : 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: iconMode ? 28 : 20,
                                backgroundColor:
                                    TsTokens.brand.withValues(alpha: 0.2),
                                child: Text(
                                  '$shownScore',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    color: TsTokens.brandSoft,
                                    fontSize: iconMode ? 16 : 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['clientNom']?.toString() ??
                                          t('client'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: iconMode ? 18 : 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      recommendationLabel(reco),
                                      style: TextStyle(
                                        color: TsTokens.textMute,
                                        fontSize: iconMode ? 15 : 13,
                                      ),
                                    ),
                                    Text(
                                      riskCategoryLabel(
                                        r['riskCategory']?.toString() ??
                                            riskCategoryFromScore(
                                              (r['score'] as num?)?.toInt() ?? 0,
                                            ),
                                      ),
                                      style: TextStyle(
                                        color: TsTokens.textMute,
                                        fontSize: iconMode ? 13 : 12,
                                      ),
                                    ),
                                    Text(
                                      _money(
                                        r['montantDemandeFcfa'] as num? ?? 0,
                                      ),
                                      style: TextStyle(
                                        color: TsTokens.brandSoft,
                                        fontSize: iconMode ? 15 : 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                synced
                                    ? Icons.cloud_done
                                    : Icons.cloud_upload,
                                color:
                                    synced ? TsTokens.ok : TsTokens.sand,
                                size: iconMode ? 28 : 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Formulaire terrain — prise en main en 4 étapes courtes.
class AgentNewDossierPage extends ConsumerStatefulWidget {
  const AgentNewDossierPage({super.key});

  @override
  ConsumerState<AgentNewDossierPage> createState() =>
      _AgentNewDossierPageState();
}

class _AgentNewDossierPageState extends ConsumerState<AgentNewDossierPage> {
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _revenu = TextEditingController(text: '100000');
  final _charges = TextEditingController(text: '30000');
  final _montant = TextEditingController(text: '100000');

  int stepIndex = 0;
  bool clientConnu = false;
  String secteur = 'commerce';
  int tailleMenage = 4;
  int incidentsPaiement = 0;
  int regulariteDepots = 2;
  int ancienneteCompteMois = 6;
  int remboursements = 2;
  int ancienneteActivite = 3;
  bool tontine = false;
  int tontineAns = 0;
  int nbGarants = 1;
  int ancienneteCoop = 1;
  String saisonnalite = 'stable';
  bool actifTerrain = false;
  bool actifBetail = false;
  bool actifMateriel = false;
  int dureeMois = 3;
  bool busy = false;

  List<_FormStep> get _flow => [
        _FormStep.client,
        _FormStep.profil,
        _FormStep.confiance,
        if (clientConnu) _FormStep.historique,
        _FormStep.capacite,
      ];

  _FormStep get _current => _flow[stepIndex.clamp(0, _flow.length - 1)];

  String _stepTitleKey(_FormStep s) => switch (s) {
        _FormStep.client => 'stepClient',
        _FormStep.profil => 'stepProfil',
        _FormStep.confiance => 'stepConfiance',
        _FormStep.historique => 'stepHistory',
        _FormStep.capacite => 'stepMoney',
      };

  String _stepHintKey(_FormStep s) => switch (s) {
        _FormStep.client => 'stepHintClient',
        _FormStep.profil => 'stepHintProfil',
        _FormStep.confiance => 'stepHintConfiance',
        _FormStep.historique => 'stepHintHistory',
        _FormStep.capacite => 'stepHintMoney',
      };

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _revenu.dispose();
    _charges.dispose();
    _montant.dispose();
    super.dispose();
  }


  void _goTo(int next) {
    setState(() => stepIndex = next.clamp(0, _flow.length - 1));
  }

  bool _validateCurrent() {
    final t = ref.read(tsStringsProvider);
    if (_current == _FormStep.client && _nom.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('nameRequired'))),
      );
      return false;
    }
    if (_current == _FormStep.capacite) {
      final revenu = _parseMoney(_revenu);
      final montant = _parseMoney(_montant);
      if (revenu <= 0 || montant <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indiquez le revenu et le montant demandé'),
          ),
        );
        return false;
      }
    }
    return true;
  }

  int _parseMoney(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

  Future<void> _submit() async {
    if (!_validateCurrent()) return;
    setState(() => busy = true);
    final input = AgentScoreInput(
      clientNom: _nom.text.trim(),
      clientTelephone: _tel.text.trim().isEmpty ? null : _tel.text.trim(),
      clientConnu: clientConnu,
      secteurActivite: secteur,
      tailleMenage: tailleMenage,
      incidentsPaiement: clientConnu ? incidentsPaiement : 0,
      regulariteDepots: clientConnu ? regulariteDepots : 0,
      ancienneteCompteMois: clientConnu ? ancienneteCompteMois : 0,
      remboursementsAnterieurs: clientConnu ? remboursements : 0,
      ancienneteActiviteAns: ancienneteActivite,
      tontine: tontine,
      tontineAns: tontine ? tontineAns : 0,
      nbGarants: nbGarants,
      ancienneteCoopAns: ancienneteCoop,
      saisonnalite: saisonnalite,
      actifTerrain: actifTerrain,
      actifBetail: actifBetail,
      actifMateriel: actifMateriel,
      revenuMensuelFcfa: _parseMoney(_revenu),
      chargesMensuellesFcfa: _parseMoney(_charges),
      montantDemandeFcfa: _parseMoney(_montant),
      dureeMois: dureeMois,
    );
    final result = computeAgentScorecard(input);
    final row = await ref.read(agentDossierStoreProvider).saveAndEnqueue(
          input: input,
          result: result,
        );
    if (!mounted) return;
    setState(() => busy = false);
    context.push('/app/dossier/${row['id']}', extra: row);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tsStringsProvider);
    final iconMode = ref.watch(uxPrefsProvider).iconMode;
    final btnH = iconMode ? 58.0 : 50.0;

    final last = _flow.length - 1;
    final current = _current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (stepIndex > 0) {
          _goTo(stepIndex - 1);
        } else {
          context.go('/app');
        }
      },
      child: Scaffold(
        backgroundColor: TsTokens.bg,
        appBar: AppBar(
          title: Text(
            t(_stepTitleKey(current)),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: TsTokens.surface,
          leading: IconButton(
            icon: Icon(
              stepIndex == 0 ? Icons.close : Icons.arrow_back,
              size: iconMode ? 28 : 24,
            ),
            onPressed: () {
              if (stepIndex == 0) {
                context.go('/app');
              } else {
                _goTo(stepIndex - 1);
              }
            },
          ),
          actions: [
            TsSpeakButton(
              text:
                  '${t.format('stepOf', {'n': '${stepIndex + 1}', 'total': '${_flow.length}'})}. ${t(_stepHintKey(current))}',
              alwaysShow: true,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _flow.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= stepIndex
                                  ? TsTokens.brand
                                  : TsTokens.line,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(_stepHintKey(current)),
                    style: GoogleFonts.outfit(
                      fontSize: iconMode ? 22 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('agentOfflineHint'),
                    style: TextStyle(
                      color: TsTokens.textMute,
                      fontSize: iconMode ? 14 : 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  if (current == _FormStep.client) ..._stepClient(t, iconMode),
                  if (current == _FormStep.profil) ..._stepProfil(t, iconMode),
                  if (current == _FormStep.confiance)
                    ..._stepConfiance(t, iconMode),
                  if (current == _FormStep.historique)
                    ..._stepHistory(t, iconMode),
                  if (current == _FormStep.capacite) ..._stepMoney(t, iconMode),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    if (current == _FormStep.historique)
                      TextButton(
                        onPressed: () => _goTo(stepIndex + 1),
                        child: Text(t('iDontKnow')),
                      ),
                    Row(
                      children: [
                        if (stepIndex > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _goTo(stepIndex - 1),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.fromHeight(btnH),
                              ),
                              child: Text(t('back')),
                            ),
                          ),
                        if (stepIndex > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: busy
                                ? null
                                : () {
                                    if (!_validateCurrent()) return;
                                    if (stepIndex < last) {
                                      _goTo(stepIndex + 1);
                                    } else {
                                      _submit();
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              minimumSize: Size.fromHeight(btnH),
                              backgroundColor: TsTokens.brand,
                              foregroundColor: TsTokens.onBrand,
                            ),
                            child: busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    stepIndex < last
                                        ? t('next')
                                        : t('computeScore'),
                                    style: TextStyle(
                                      fontSize: iconMode ? 17 : 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepClient(TsStrings t, bool iconMode) => [
        TextField(
          controller: _nom,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t('clientName'),
            contentPadding: iconMode
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                : null,
          ),
          style: TextStyle(fontSize: iconMode ? 20 : 16),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tel,
          decoration: InputDecoration(
            labelText: t('phoneOptional'),
            contentPadding: iconMode
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                : null,
          ),
          style: TextStyle(fontSize: iconMode ? 20 : 16),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        Text(
          t('knownClientAsk'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: iconMode ? 17 : 15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _bigChoice(
                label: t('knownClientYes'),
                selected: clientConnu,
                iconMode: iconMode,
                onTap: () => setState(() => clientConnu = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigChoice(
                label: t('knownClientNo'),
                selected: !clientConnu,
                iconMode: iconMode,
                onTap: () => setState(() => clientConnu = false),
              ),
            ),
          ],
        ),
      ];

  List<Widget> _stepProfil(TsStrings t, bool iconMode) => [
        Text(
          t('sectorAsk'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: iconMode ? 17 : 15,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in [
              ('commerce', t('commerce')),
              ('artisanat', t('craft')),
              ('agriculture', t('sectorAgri')),
              ('elevage', t('sectorLivestock')),
              ('transport', t('sectorTransport')),
              ('restauration', t('food')),
              ('autre', t('idOther')),
            ])
              ChoiceChip(
                label: Text(
                  e.$2,
                  style: TextStyle(fontSize: iconMode ? 15 : 13),
                ),
                selected: secteur == e.$1,
                onSelected: (_) => setState(() => secteur = e.$1),
                selectedColor: TsTokens.brand.withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _sliderInt(
          t('activityAgeAsk'),
          ancienneteActivite,
          0,
          15,
          (v) => setState(() => ancienneteActivite = v),
          iconMode: iconMode,
          suffix: ' ans',
        ),
        _sliderInt(
          t('householdAsk'),
          tailleMenage,
          1,
          20,
          (v) => setState(() => tailleMenage = v),
          iconMode: iconMode,
          suffix: t('householdSuffix'),
        ),
        const SizedBox(height: 8),
        Text(
          t('seasonAsk'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: iconMode ? 17 : 15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in [
              ('stable', t('seasonStable')),
              ('moderee', t('seasonMild')),
              ('forte', t('seasonStrong')),
            ]) ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _bigChoice(
                    label: e.$2,
                    selected: saisonnalite == e.$1,
                    iconMode: iconMode,
                    onTap: () {
                      setState(() => saisonnalite = e.$1);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t('assetsAsk'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: iconMode ? 17 : 15,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _assetChip(t('assetLand'), Icons.landscape_outlined, actifTerrain,
                (v) => setState(() => actifTerrain = v), iconMode),
            _assetChip(t('assetCattle'), Icons.pets_outlined, actifBetail,
                (v) => setState(() => actifBetail = v), iconMode),
            _assetChip(t('assetTools'), Icons.build_outlined, actifMateriel,
                (v) => setState(() => actifMateriel = v), iconMode),
          ],
        ),
      ];

  List<Widget> _stepConfiance(TsStrings t, bool iconMode) => [
        Text(
          t('tontineAsk'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: iconMode ? 17 : 15,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _bigChoice(
                label: t('yes'),
                selected: tontine,
                iconMode: iconMode,
                onTap: () {
                  setState(() => tontine = true);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigChoice(
                label: t('no'),
                selected: !tontine,
                iconMode: iconMode,
                onTap: () {
                  setState(() {
                    tontine = false;
                    tontineAns = 0;
                  });
                },
              ),
            ),
          ],
        ),
        if (tontine) ...[
          const SizedBox(height: 12),
          _sliderInt(
            t('tontineYearsAsk'),
            tontineAns,
            0,
            10,
            (v) => setState(() => tontineAns = v),
            iconMode: iconMode,
            suffix: ' ans',
          ),
        ],
        const SizedBox(height: 12),
        _sliderInt(
          t('guarantorsAsk'),
          nbGarants,
          0,
          5,
          (v) => setState(() => nbGarants = v),
          iconMode: iconMode,
        ),
        _sliderInt(
          t('coopAgeAsk'),
          ancienneteCoop,
          0,
          10,
          (v) => setState(() => ancienneteCoop = v),
          iconMode: iconMode,
          suffix: ' ans',
        ),
      ];

  List<Widget> _stepHistory(TsStrings t, bool iconMode) => [
        _choiceRow(
          t('depositsAsk'),
          iconMode,
          options: const [
            (0, 'Jamais'),
            (1, 'Rarement'),
            (2, 'Parfois'),
            (3, 'Souvent'),
            (4, 'Toujours'),
          ],
          value: regulariteDepots,
          onChanged: (v) => setState(() => regulariteDepots = v),
        ),
        const SizedBox(height: 18),
        _sliderInt(
          t('accountAgeAsk'),
          ancienneteCompteMois,
          0,
          36,
          (v) => setState(() => ancienneteCompteMois = v),
          iconMode: iconMode,
          suffix: ' mois',
        ),
        const SizedBox(height: 12),
        _choiceRow(
          t('repayAsk'),
          iconMode,
          options: const [
            (0, 'Jamais'),
            (1, 'Moyen'),
            (2, 'Bien'),
            (3, 'Très bien'),
          ],
          value: remboursements,
          onChanged: (v) => setState(() => remboursements = v),
        ),
        const SizedBox(height: 12),
        _choiceRow(
          t('incidentsAsk'),
          iconMode,
          options: [
            (0, t('incidentsNone')),
            (1, t('incidentsSome')),
            (2, t('incidentsMany')),
          ],
          value: incidentsPaiement,
          onChanged: (v) => setState(() => incidentsPaiement = v),
        ),
      ];

  List<Widget> _stepMoney(TsStrings t, bool iconMode) => [
        TextField(
          controller: _revenu,
          decoration: InputDecoration(
            labelText: t('incomeAsk'),
            contentPadding: iconMode
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                : null,
          ),
          style: TextStyle(fontSize: iconMode ? 20 : 16),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _charges,
          decoration: InputDecoration(
            labelText: t('chargesAsk'),
            contentPadding: iconMode
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                : null,
          ),
          style: TextStyle(fontSize: iconMode ? 20 : 16),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _montant,
          decoration: InputDecoration(
            labelText: t('requestAsk'),
            contentPadding: iconMode
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                : null,
          ),
          style: TextStyle(fontSize: iconMode ? 20 : 16),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _sliderInt(
          t('durationAsk'),
          dureeMois,
          1,
          12,
          (v) => setState(() => dureeMois = v),
          iconMode: iconMode,
          suffix: ' mois',
        ),
      ];

  Widget _assetChip(
    String label,
    IconData icon,
    bool selected,
    ValueChanged<bool> onChanged,
    bool iconMode,
  ) {
    return FilterChip(
      selected: selected,
      avatar: Icon(icon, size: iconMode ? 22 : 18),
      label: Text(
        label,
        style: TextStyle(fontSize: iconMode ? 15 : 13),
      ),
      selectedColor: TsTokens.brand.withValues(alpha: 0.25),
      checkmarkColor: TsTokens.brand,
      onSelected: (v) => onChanged(v),
      padding: EdgeInsets.symmetric(
        horizontal: iconMode ? 10 : 6,
        vertical: iconMode ? 10 : 4,
      ),
    );
  }

  Widget _bigChoice({
    required String label,
    required bool selected,
    required bool iconMode,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? TsTokens.brand.withValues(alpha: 0.2)
          : TsTokens.elevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: iconMode ? 18 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? TsTokens.brand : TsTokens.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: iconMode ? 17 : 15,
              color: selected ? TsTokens.brandSoft : TsTokens.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceRow(
    String title,
    bool iconMode, {
    required List<(int, String)> options,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: iconMode ? 17 : 15,
                ),
              ),
            ),
            TsSpeakButton(text: title, compact: true),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(
                  o.$2,
                  style: TextStyle(fontSize: iconMode ? 15 : 13),
                ),
                selected: value == o.$1,
                onSelected: (_) {
                  onChanged(o.$1);
                },
                selectedColor: TsTokens.brand.withValues(alpha: 0.25),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: iconMode ? 10 : 6,
                  vertical: iconMode ? 4 : 0,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sliderInt(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    bool iconMode = false,
    String suffix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: iconMode ? 16 : 14,
                ),
              ),
            ),
            Text(
              '$value$suffix',
              style: TextStyle(
                color: TsTokens.brandSoft,
                fontWeight: FontWeight.w700,
                fontSize: iconMode ? 16 : 14,
              ),
            ),
            TsSpeakButton(
              text: '$label : $value$suffix',
              compact: true,
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) {
            final next = v.round();
            onChanged(next);          },
        ),
      ],
    );
  }
}
/// Résultat explicable + aide à la décision.
class AgentDossierDetailPage extends ConsumerWidget {
  const AgentDossierDetailPage({super.key, required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultMap = Map<String, dynamic>.from(row['result'] as Map? ?? {});
    final result = AgentScoreResult.fromJson(resultMap);
    final reco = result.recommendation;
    final t = ref.watch(tsStringsProvider);
    final iconMode = ref.watch(uxPrefsProvider).iconMode;
    final clientName = row['clientNom']?.toString() ?? t('client');
    final score = result.score850;
    final announce =
        '$clientName. Score $score. ${riskCategoryLabel(result.riskCategory)}. ${recommendationLabel(reco)}.';

    return TsVoiceOnOpen(
      text: announce,
      child: Scaffold(
        backgroundColor: TsTokens.bg,
        appBar: AppBar(
          title: Text(
            clientName,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: TsTokens.surface,
          actions: [
            TsSpeakButton(text: announce, alwaysShow: true),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _agentCard(
              child: Column(
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.outfit(
                      fontSize: iconMode ? 64 : 56,
                      fontWeight: FontWeight.w800,
                      color: TsTokens.brand,
                    ),
                  ),
                  Text(
                    t('scoreScale'),
                    style: TextStyle(
                      color: TsTokens.textMute,
                      fontSize: iconMode ? 13 : 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    riskCategoryLabel(result.riskCategory),
                    style: GoogleFonts.outfit(
                      fontSize: iconMode ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: TsTokens.brandSoft,
                    ),
                  ),
                  Text(
                    recommendationLabel(reco),
                    style: GoogleFonts.outfit(
                      fontSize: iconMode ? 20 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Aide à la décision — ne remplace pas l'analyse de l'agent.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TsTokens.textMute,
                      fontSize: iconMode ? 14 : 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _agentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('repayCapacity'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: iconMode ? 17 : 15,
                          ),
                        ),
                      ),
                      TsSpeakButton(
                        text:
                            '${t('repayCapacity')}. Taux de charge ${(result.chargeRate * 100).toStringAsFixed(0)} pour cent.',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _kv(t('dtiLabel'),
                      '${(result.chargeRate * 100).toStringAsFixed(0)} %'),
                  _kv(t('estInstallment'), _money(result.echeanceEstimeeFcfa)),
                  _kv(t('recommendedAmount'),
                      _money(result.montantSoutenableFcfa)),
                  _kv(t('requestedAmount'),
                      _money(row['montantDemandeFcfa'] as num? ?? 0)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _agentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('topDrivers'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: iconMode ? 17 : 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final d in result.drivers)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: iconMode ? 10 : 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(fontSize: iconMode ? 16 : 14),
                            ),
                          ),
                          Text(
                            '+${d.delta}',
                            style: TextStyle(
                              color: TsTokens.brandSoft,
                              fontWeight: FontWeight.w700,
                              fontSize: iconMode ? 16 : 14,
                            ),
                          ),
                          TsSpeakButton(
                            text: '${d.label} : plus ${d.delta}',
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.go('/app'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(iconMode ? 56 : 48),
              ),
              child: Text(t('backToDossiers')),
            ),
            TextButton(
              onPressed: () => context.go('/app/nouveau'),
              child: Text(t('newDossierFull')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k, style: TextStyle(color: TsTokens.textMute))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Ecran sync / file d'attente.
class AgentSyncPage extends ConsumerStatefulWidget {
  const AgentSyncPage({super.key});

  @override
  ConsumerState<AgentSyncPage> createState() => _AgentSyncPageState();
}

class _AgentSyncPageState extends ConsumerState<AgentSyncPage> {
  bool busy = false;

  Future<void> _syncNow() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(syncServiceProvider).flush();
      await ref.read(agentDossierStoreProvider).refreshSyncedFlags();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(syncPendingProvider);
    final err = ref.watch(syncErrorProvider);
    final queue = ref.watch(offlineQueueProvider);
    final items = queue.list();
    final t = ref.watch(tsStringsProvider);
    final iconMode = ref.watch(uxPrefsProvider).iconMode;
    final announce = pending > 0
        ? '${t('syncTitle')}. $pending ${t('pendingSends')}.'
        : '${t('syncTitle')}. ${t('syncAllDone')}';

    return TsVoiceOnOpen(
      text: announce,
      child: Scaffold(
        backgroundColor: TsTokens.bg,
        appBar: AppBar(
          title: Text(
            t('syncTitle'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          backgroundColor: TsTokens.surface,
          actions: [
            TsSpeakButton(text: announce, alwaysShow: true),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _agentCard(
                child: Column(
                  children: [
                    Text(
                      '$pending',
                      style: GoogleFonts.outfit(
                        fontSize: iconMode ? 48 : 40,
                        fontWeight: FontWeight.w800,
                        color: TsTokens.brand,
                      ),
                    ),
                    Text(
                      t('pendingSends'),
                      style: TextStyle(fontSize: iconMode ? 16 : 14),
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        err,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TsTokens.danger),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : _syncNow,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(iconMode ? 58 : 48),
                      ),
                      label: Text(
                        busy ? t('syncing') : t('syncNow'),
                        style: TextStyle(fontSize: iconMode ? 16 : 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('offlineQueue'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: iconMode ? 17 : 15,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          t('syncAllDone'),
                          style: TextStyle(
                            color: TsTokens.textMute,
                            fontSize: iconMode ? 16 : 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final m = items[i];
                          final statusFr = switch (m.status) {
                            'failed' => 'Échoué',
                            'pending' => 'En attente',
                            'synced' => 'Envoyé',
                            _ => m.status,
                          };
                          final kindFr = switch (m.kind) {
                            'create_agent_dossier' => 'Dossier scoring',
                            'agent_scorecard' => 'Score client',
                            'create_tontine' => 'Création tontine',
                            'cotisation' => 'Cotisation',
                            _ => m.kind.replaceAll('_', ' '),
                          };
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: iconMode ? 6 : 0,
                              horizontal: 8,
                            ),
                            title: Text(
                              kindFr,
                              style: TextStyle(fontSize: iconMode ? 16 : 14),
                            ),
                            subtitle: Text(
                              m.failReason == null || m.failReason!.isEmpty
                                  ? statusFr
                                  : '$statusFr — ${m.failReason}',
                            ),
                            trailing: m.status == 'failed'
                                ? TextButton(
                                    onPressed: () async {
                                      await queue
                                          .retryFailed(m.clientMutationId);
                                      await ref
                                          .read(syncServiceProvider)
                                          .refreshCount();
                                    },
                                    child: Text(t('retrySync')),
                                  )
                                : TsSpeakButton(
                                    text: '$kindFr. $statusFr',
                                    compact: true,
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
