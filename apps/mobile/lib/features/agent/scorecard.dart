/// Scorecard DigiCoop — calcul 100 % local (miroir de packages/neoscore agent-scorecard).
library;

class AgentScoreInput {
  AgentScoreInput({
    required this.clientNom,
    this.clientTelephone,
    this.clientConnu = false,
    this.secteurActivite = 'commerce',
    this.tailleMenage = 1,
    this.incidentsPaiement = 0,
    this.regulariteDepots = 0,
    this.ancienneteCompteMois = 0,
    this.remboursementsAnterieurs = 0,
    this.ancienneteActiviteAns = 0,
    this.tontine = false,
    this.tontineAns = 0,
    this.nbGarants = 0,
    this.ancienneteCoopAns = 0,
    this.saisonnalite = 'stable',
    this.actifTerrain = false,
    this.actifBetail = false,
    this.actifMateriel = false,
    required this.revenuMensuelFcfa,
    this.chargesMensuellesFcfa = 0,
    required this.montantDemandeFcfa,
    this.dureeMois = 3,
  });

  final String clientNom;
  final String? clientTelephone;
  final bool clientConnu;
  final String secteurActivite;
  final int tailleMenage;
  final int incidentsPaiement;
  final int regulariteDepots;
  final int ancienneteCompteMois;
  final int remboursementsAnterieurs;
  final int ancienneteActiviteAns;
  final bool tontine;
  final int tontineAns;
  final int nbGarants;
  final int ancienneteCoopAns;
  final String saisonnalite;
  final bool actifTerrain;
  final bool actifBetail;
  final bool actifMateriel;
  final int revenuMensuelFcfa;
  final int chargesMensuellesFcfa;
  final int montantDemandeFcfa;
  final int dureeMois;

  Map<String, dynamic> toJson() => {
        'clientNom': clientNom,
        if (clientTelephone != null) 'clientTelephone': clientTelephone,
        'clientConnu': clientConnu,
        'secteurActivite': secteurActivite,
        'tailleMenage': tailleMenage,
        'incidentsPaiement': incidentsPaiement,
        'regulariteDepots': regulariteDepots,
        'ancienneteCompteMois': ancienneteCompteMois,
        'remboursementsAnterieurs': remboursementsAnterieurs,
        'ancienneteActiviteAns': ancienneteActiviteAns,
        'tontine': tontine,
        'tontineAns': tontineAns,
        'nbGarants': nbGarants,
        'ancienneteCoopAns': ancienneteCoopAns,
        'saisonnalite': saisonnalite,
        'actifTerrain': actifTerrain,
        'actifBetail': actifBetail,
        'actifMateriel': actifMateriel,
        'revenuMensuelFcfa': revenuMensuelFcfa,
        'chargesMensuellesFcfa': chargesMensuellesFcfa,
        'montantDemandeFcfa': montantDemandeFcfa,
        'dureeMois': dureeMois,
      };
}

class AgentScoreDriver {
  AgentScoreDriver({
    required this.key,
    required this.label,
    required this.delta,
  });

  final String key;
  final String label;
  final num delta;

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'delta': delta,
      };

  factory AgentScoreDriver.fromJson(Map<String, dynamic> j) => AgentScoreDriver(
        key: j['key'] as String,
        label: j['label'] as String,
        delta: j['delta'] as num,
      );
}

class AgentScoreResult {
  AgentScoreResult({
    required this.score,
    required this.recommendation,
    required this.riskCategory,
    required this.drivers,
    required this.chargeRate,
    required this.montantSoutenableFcfa,
    required this.echeanceEstimeeFcfa,
    required this.revenuMensuelFcfa,
    required this.computedAt,
  });

  /// Échelle 300–850 (anciens dossiers 0–100 convertis à l’affichage).
  final int score;
  final String recommendation;
  final String riskCategory;
  final List<AgentScoreDriver> drivers;
  final double chargeRate;
  final int montantSoutenableFcfa;
  final int echeanceEstimeeFcfa;
  final int revenuMensuelFcfa;
  final String computedAt;

  int get score850 => score <= 100 ? (300 + (score * 5.5).round()) : score;

  Map<String, dynamic> toJson() => {
        'score': score,
        'recommendation': recommendation,
        'riskCategory': riskCategory,
        'drivers': drivers.map((d) => d.toJson()).toList(),
        'chargeRate': chargeRate,
        'montantSoutenableFcfa': montantSoutenableFcfa,
        'echeanceEstimeeFcfa': echeanceEstimeeFcfa,
        'revenuMensuelFcfa': revenuMensuelFcfa,
        'computedAt': computedAt,
      };

  factory AgentScoreResult.fromJson(Map<String, dynamic> j) {
    final rawScore = (j['score'] as num?)?.toInt() ?? 0;
    final score850 = rawScore <= 100 ? (300 + (rawScore * 5.5).round()) : rawScore;
    return AgentScoreResult(
      score: score850,
      recommendation: j['recommendation'] as String? ?? 'a_reexaminer',
      riskCategory: j['riskCategory'] as String? ?? riskCategoryFromScore(score850),
      drivers: ((j['drivers'] as List?) ?? [])
          .map((e) => AgentScoreDriver.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      chargeRate: (j['chargeRate'] as num?)?.toDouble() ?? 0,
      montantSoutenableFcfa: (j['montantSoutenableFcfa'] as num?)?.toInt() ?? 0,
      echeanceEstimeeFcfa: (j['echeanceEstimeeFcfa'] as num?)?.toInt() ?? 0,
      revenuMensuelFcfa: (j['revenuMensuelFcfa'] as num?)?.toInt() ?? 0,
      computedAt: j['computedAt'] as String? ?? '',
    );
  }
}

const _loanMonthlyRate = 0.025;
const _maxChargeRate = 0.4;
const _targetChargeRate = 0.35;

int _clamp(num n, [int min = 0, int max = 100]) =>
    n < min ? min : (n > max ? max : n.round());

int _toScale850(int score100) => 300 + (_clamp(score100) * 5.5).round();

int _estimatedInstallment(int principal, int months) {
  if (principal <= 0 || months <= 0) return 0;
  final factor = _pow(1 + _loanMonthlyRate, months);
  final payment =
      (principal * _loanMonthlyRate * factor) / (factor - 1);
  return payment.round();
}

int _maxPrincipalFromPayment(int payment, int months) {
  if (payment <= 0 || months <= 0) return 0;
  final factor = _pow(1 + _loanMonthlyRate, months);
  return ((payment * (factor - 1)) / (_loanMonthlyRate * factor)).round();
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

String riskCategoryFromScore(int score850) {
  if (score850 >= 700) return 'faible';
  if (score850 >= 575) return 'modere';
  return 'eleve';
}

AgentScoreResult computeAgentScorecard(AgentScoreInput input) {
  final parts = <({String key, String label, int points, int max})>[];

  if (input.clientConnu) {
    final depotsPts = const [0, 6, 12, 18, 24][input.regulariteDepots.clamp(0, 4)];
    parts.add((
      key: 'regulariteDepots',
      label: 'Régularité des dépôts',
      points: depotsPts,
      max: 24,
    ));

    final comptePts = input.ancienneteCompteMois >= 24
        ? 12
        : input.ancienneteCompteMois >= 12
            ? 8
            : input.ancienneteCompteMois >= 6
                ? 4
                : 0;
    parts.add((
      key: 'ancienneteCompte',
      label: 'Ancienneté du compte',
      points: comptePts,
      max: 12,
    ));

    final rembPts =
        const [0, 5, 10, 14][input.remboursementsAnterieurs.clamp(0, 3)];
    parts.add((
      key: 'remboursements',
      label: 'Remboursements antérieurs',
      points: rembPts,
      max: 14,
    ));

    final incidentPts = const [8, 4, 0][input.incidentsPaiement.clamp(0, 2)];
    parts.add((
      key: 'incidentsPaiement',
      label: 'Incidents de paiement',
      points: incidentPts,
      max: 8,
    ));
  }

  final actPts = input.ancienneteActiviteAns >= 5
      ? 16
      : input.ancienneteActiviteAns >= 3
          ? 12
          : input.ancienneteActiviteAns >= 1
              ? 7
              : 2;
  parts.add((
    key: 'ancienneteActivite',
    label: "Ancienneté de l'activité",
    points: actPts,
    max: 16,
  ));

  var tontinePts = 0;
  if (input.tontine) {
    tontinePts = input.tontineAns >= 3 ? 12 : input.tontineAns >= 1 ? 8 : 5;
  }
  parts.add((
    key: 'tontine',
    label: 'Appartenance à une tontine',
    points: tontinePts,
    max: 12,
  ));

  final garantPts = (input.nbGarants * 5).clamp(0, 14);
  parts.add((
    key: 'garants',
    label: 'Garants dans le réseau',
    points: garantPts,
    max: 14,
  ));

  final coopPts = input.ancienneteCoopAns >= 3
      ? 10
      : input.ancienneteCoopAns >= 1
          ? 6
          : 0;
  parts.add((
    key: 'ancienneteCoop',
    label: 'Relation avec la coopérative',
    points: coopPts,
    max: 10,
  ));

  final saisonPts = input.saisonnalite == 'stable'
      ? 6
      : input.saisonnalite == 'moderee'
          ? 3
          : 0;
  parts.add((
    key: 'saisonnalite',
    label: 'Saisonnalité du revenu',
    points: saisonPts,
    max: 6,
  ));

  final actifsPts = (input.actifTerrain ? 4 : 0) +
      (input.actifBetail ? 3 : 0) +
      (input.actifMateriel ? 3 : 0);
  parts.add((
    key: 'actifs',
    label: 'Actifs simples (terrain, bétail, matériel)',
    points: actifsPts,
    max: 10,
  ));

  final raw = parts.fold<int>(0, (s, p) => s + p.points);
  final maxRaw = parts.fold<int>(0, (s, p) => s + p.max);
  var score100 = _clamp((raw / maxRaw) * 100);

  final months = input.dureeMois > 0 ? input.dureeMois : 3;
  final echeance = _estimatedInstallment(input.montantDemandeFcfa, months);
  final revenu = input.revenuMensuelFcfa < 0 ? 0 : input.revenuMensuelFcfa;
  final charges =
      input.chargesMensuellesFcfa < 0 ? 0 : input.chargesMensuellesFcfa;
  final chargeRate = revenu > 0 ? (charges + echeance) / revenu : 999.0;

  if (chargeRate > _maxChargeRate) {
    score100 = _clamp(score100 - 15);
  } else if (chargeRate > _targetChargeRate) {
    score100 = _clamp(score100 - 8);
  }

  final score = _toScale850(score100);

  final maxPayment = (revenu * _targetChargeRate - charges).round();
  final montantSoutenable =
      _maxPrincipalFromPayment(maxPayment < 0 ? 0 : maxPayment, months);

  final sorted = [...parts]..sort((a, b) => b.points.abs() - a.points.abs());
  final drivers = sorted
      .take(3)
      .map((p) => AgentScoreDriver(key: p.key, label: p.label, delta: p.points))
      .toList();

  String recommendation;
  if (score >= 685 && chargeRate <= _targetChargeRate) {
    recommendation = 'recommande';
  } else if (score >= 575 && chargeRate <= _maxChargeRate) {
    recommendation = 'analyse_complementaire';
  } else {
    recommendation = 'a_reexaminer';
  }
  if (chargeRate > _maxChargeRate && recommendation == 'recommande') {
    recommendation = 'analyse_complementaire';
  }

  return AgentScoreResult(
    score: score,
    recommendation: recommendation,
    riskCategory: riskCategoryFromScore(score),
    drivers: drivers,
    chargeRate: (chargeRate * 1000).round() / 1000,
    montantSoutenableFcfa: montantSoutenable < 0 ? 0 : montantSoutenable,
    echeanceEstimeeFcfa: echeance,
    revenuMensuelFcfa: revenu,
    computedAt: DateTime.now().toUtc().toIso8601String(),
  );
}

String recommendationLabel(String code) {
  switch (code) {
    case 'recommande':
      return 'Dossier recommandé';
    case 'analyse_complementaire':
      return 'Analyse complémentaire';
    case 'a_reexaminer':
      return 'À réexaminer';
    default:
      return code;
  }
}

String riskCategoryLabel(String code) {
  switch (code) {
    case 'faible':
      return 'Risque faible';
    case 'modere':
      return 'Risque modéré';
    case 'eleve':
      return 'Risque élevé';
    default:
      return code;
  }
}
