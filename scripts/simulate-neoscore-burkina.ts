/**
 * Simulation NeoScore — profils réalistes secteur informel Burkina Faso
 * (Ouagadougou / Bobo-Dioulasso / zones périurbaines).
 *
 * Usage: npx tsx scripts/simulate-neoscore-burkina.ts
 */
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildOfferAmount,
  computeNeoScore,
} from "../packages/neoscore/src/index.ts";
import type { ScoreFeatures } from "../packages/shared/src/score.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "../docs/simulations");

type Persona = {
  id: string;
  nom: string;
  genre: "femme" | "homme";
  ville: string;
  zone: string;
  metier: string;
  description: string;
  /** Profil déclaré (labels métier / terrain) */
  profil: {
    ancienneteLabel: string;
    caJourLabel: string;
    tontine: boolean;
    tontineCotis: number;
    mobileMoney: string;
    compte: string;
    chargesFixesMensuelles: number;
    saisonnalite: "stable" | "moderee" | "forte";
    garantieSolidaire: boolean;
  };
  /** Features numériques pour le moteur */
  features: ScoreFeatures;
  /** Résumé cahier 30 j (pour le PDF) */
  cahier: {
    ventesFcfa: number;
    depensesFcfa: number;
    creancesOuvertesFcfa: number;
    creancesRetard: number;
    nbOperations: number;
    semainesActives: number;
  };
};

const CA_MID: Record<string, number> = {
  m5k: 2_500,
  "5_15k": 10_000,
  "15_30k": 22_500,
  "30_60k": 45_000,
  "60_100k": 80_000,
  p100k: 120_000,
};

function feat(
  over: Partial<ScoreFeatures> & {
    caJourLabel?: string;
    salesLast30Fcfa: number;
  }
): ScoreFeatures {
  const caJour =
    over.caJour ??
    ({
      m5k: 1,
      "5_15k": 2,
      "15_30k": 3,
      "30_60k": 4,
      "60_100k": 5,
      p100k: 6,
    }[over.caJourLabel ?? "15_30k"] ?? 3);
  const mid =
    over.declaredCaMidpointFcfa ??
    CA_MID[over.caJourLabel ?? "15_30k"] ??
    22_500;
  const sales = over.salesLast30Fcfa;
  return {
    anciennete: 3,
    caJour,
    partCredit: 1,
    impayes: 0,
    tontine: false,
    tontineAns: 0,
    mobileMoney: 1,
    telephone: 2,
    compte: 0,
    creditHist: 0,
    opsLast30Days: 12,
    salesLast30Fcfa: sales,
    openDebtsFcfa: 0,
    overdueDebtsCount: 0,
    expensesLast30Fcfa: Math.round(sales * 0.35),
    monthlyFixedChargesFcfa: 15_000,
    tontineCotisations30Fcfa: 0,
    declaredCaMidpointFcfa: mid,
    salesVsDeclaredRatio: sales / (mid * 30),
    activeWeeksLast30: 4,
    saisonnalite: "stable",
    garantieSolidaire: false,
    ...over,
    caJour,
    declaredCaMidpointFcfa: mid,
    salesVsDeclaredRatio: sales / (mid * 30),
  };
}

/** 12 personas ancrées dans la réalité informelle BF (prix FCFA 2025–2026). */
const PERSONAS: Persona[] = [
  {
    id: "BF-SIM-01",
    nom: "Aminata Ouédraogo",
    genre: "femme",
    ville: "Ouagadougou",
    zone: "Marché Sankaryaré",
    metier: "commerce",
    description:
      "Revendeuse de céréales et condiments. Tontine mensuelle 10 000 FCFA, Orange Money quotidien, peu de créances.",
    profil: {
      ancienneteLabel: "6_10",
      caJourLabel: "30_60k",
      tontine: true,
      tontineCotis: 10_000,
      mobileMoney: "quotidien",
      compte: "non",
      chargesFixesMensuelles: 25_000,
      saisonnalite: "moderee",
      garantieSolidaire: true,
    },
    features: feat({
      anciennete: 4,
      caJourLabel: "30_60k",
      tontine: true,
      tontineAns: 3,
      mobileMoney: 3,
      creditHist: 1,
      opsLast30Days: 22,
      salesLast30Fcfa: 980_000,
      expensesLast30Fcfa: 420_000,
      monthlyFixedChargesFcfa: 25_000,
      tontineCotisations30Fcfa: 10_000,
      openDebtsFcfa: 45_000,
      impayes: 0,
      overdueDebtsCount: 0,
      partCredit: 1,
      activeWeeksLast30: 5,
      saisonnalite: "moderee",
      garantieSolidaire: true,
    }),
    cahier: {
      ventesFcfa: 980_000,
      depensesFcfa: 420_000,
      creancesOuvertesFcfa: 45_000,
      creancesRetard: 0,
      nbOperations: 22,
      semainesActives: 5,
    },
  },
  {
    id: "BF-SIM-02",
    nom: "Issouf Sawadogo",
    genre: "homme",
    ville: "Ouagadougou",
    zone: "Zone du bois / Kossodo",
    metier: "mecanique",
    description:
      "Mécanicien moto. CA irrégulier, créances clients atelier en retard, Moov Money occasionnel.",
    profil: {
      ancienneteLabel: "3_5",
      caJourLabel: "15_30k",
      tontine: false,
      tontineCotis: 0,
      mobileMoney: "occasionnel",
      compte: "oui_dormant",
      chargesFixesMensuelles: 40_000,
      saisonnalite: "stable",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 3,
      caJourLabel: "15_30k",
      mobileMoney: 1,
      compte: 1,
      opsLast30Days: 14,
      salesLast30Fcfa: 420_000,
      expensesLast30Fcfa: 210_000,
      monthlyFixedChargesFcfa: 40_000,
      openDebtsFcfa: 180_000,
      impayes: 2,
      overdueDebtsCount: 2,
      partCredit: 3,
      creditHist: 0,
      activeWeeksLast30: 4,
    }),
    cahier: {
      ventesFcfa: 420_000,
      depensesFcfa: 210_000,
      creancesOuvertesFcfa: 180_000,
      creancesRetard: 2,
      nbOperations: 14,
      semainesActives: 4,
    },
  },
  {
    id: "BF-SIM-03",
    nom: "Fatoumata Konaté",
    genre: "femme",
    ville: "Bobo-Dioulasso",
    zone: "Secteur 5 — maquis",
    metier: "restauration",
    description:
      "Tenancière de maquis. Forte saisonnalité (pluies) : CA déclaré abaissé à 15–30 k/j, tontine, cahier suivi.",
    profil: {
      ancienneteLabel: "6_10",
      caJourLabel: "15_30k",
      tontine: true,
      tontineCotis: 15_000,
      mobileMoney: "regulier",
      compte: "non",
      chargesFixesMensuelles: 35_000,
      saisonnalite: "forte",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 4,
      caJourLabel: "15_30k",
      tontine: true,
      tontineAns: 4,
      mobileMoney: 2,
      opsLast30Days: 16,
      salesLast30Fcfa: 520_000,
      expensesLast30Fcfa: 340_000,
      monthlyFixedChargesFcfa: 35_000,
      tontineCotisations30Fcfa: 15_000,
      openDebtsFcfa: 30_000,
      partCredit: 1,
      saisonnalite: "forte",
      activeWeeksLast30: 4,
      creditHist: 1,
    }),
    cahier: {
      ventesFcfa: 520_000,
      depensesFcfa: 340_000,
      creancesOuvertesFcfa: 30_000,
      creancesRetard: 0,
      nbOperations: 16,
      semainesActives: 4,
    },
  },
  {
    id: "BF-SIM-04",
    nom: "Boukary Compaoré",
    genre: "homme",
    ville: "Ouagadougou",
    zone: "Dassasgho",
    metier: "transport",
    description:
      "Conducteur moto-taxi (wôro-wôro). Orange Money quotidien, faible ancienneté (1–2 ans), activité encore irrégulière.",
    profil: {
      ancienneteLabel: "1_2",
      caJourLabel: "5_15k",
      tontine: false,
      tontineCotis: 0,
      mobileMoney: "quotidien",
      compte: "non",
      chargesFixesMensuelles: 20_000,
      saisonnalite: "stable",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 2,
      caJourLabel: "5_15k",
      mobileMoney: 3,
      opsLast30Days: 8,
      salesLast30Fcfa: 240_000,
      expensesLast30Fcfa: 160_000,
      monthlyFixedChargesFcfa: 20_000,
      openDebtsFcfa: 40_000,
      partCredit: 2,
      activeWeeksLast30: 3,
      creditHist: 0,
      impayes: 0,
      overdueDebtsCount: 0,
    }),
    cahier: {
      ventesFcfa: 240_000,
      depensesFcfa: 160_000,
      creancesOuvertesFcfa: 40_000,
      creancesRetard: 0,
      nbOperations: 8,
      semainesActives: 3,
    },
  },
  {
    id: "BF-SIM-05",
    nom: "Mariam Zongo",
    genre: "femme",
    ville: "Ouagadougou",
    zone: "Gounghin",
    metier: "artisanat",
    description:
      "Couturière à domicile. CA déclaré trop optimiste (15–30 k/j) face à un cahier réel faible — risque de sur-déclaration.",
    profil: {
      ancienneteLabel: "3_5",
      caJourLabel: "15_30k",
      tontine: true,
      tontineCotis: 5_000,
      mobileMoney: "occasionnel",
      compte: "non",
      chargesFixesMensuelles: 18_000,
      saisonnalite: "moderee",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 3,
      caJourLabel: "15_30k",
      tontine: true,
      tontineAns: 2,
      mobileMoney: 1,
      opsLast30Days: 4,
      salesLast30Fcfa: 85_000,
      expensesLast30Fcfa: 40_000,
      monthlyFixedChargesFcfa: 18_000,
      tontineCotisations30Fcfa: 5_000,
      activeWeeksLast30: 2,
      saisonnalite: "moderee",
    }),
    cahier: {
      ventesFcfa: 85_000,
      depensesFcfa: 40_000,
      creancesOuvertesFcfa: 0,
      creancesRetard: 0,
      nbOperations: 4,
      semainesActives: 2,
    },
  },
  {
    id: "BF-SIM-06",
    nom: "Abdoulaye Traoré",
    genre: "homme",
    ville: "Koudougou",
    zone: "Périurbain",
    metier: "agriculture",
    description:
      "Maraîcher. Saisonnalité forte, ventes groupées, tontine villageoise, garantie solidaire.",
    profil: {
      ancienneteLabel: "p10",
      caJourLabel: "5_15k",
      tontine: true,
      tontineCotis: 8_000,
      mobileMoney: "regulier",
      compte: "non",
      chargesFixesMensuelles: 12_000,
      saisonnalite: "forte",
      garantieSolidaire: true,
    },
    features: feat({
      anciennete: 5,
      caJourLabel: "5_15k",
      tontine: true,
      tontineAns: 5,
      mobileMoney: 2,
      opsLast30Days: 10,
      salesLast30Fcfa: 280_000,
      expensesLast30Fcfa: 90_000,
      monthlyFixedChargesFcfa: 12_000,
      tontineCotisations30Fcfa: 8_000,
      saisonnalite: "forte",
      garantieSolidaire: true,
      creditHist: 1,
      activeWeeksLast30: 4,
    }),
    cahier: {
      ventesFcfa: 280_000,
      depensesFcfa: 90_000,
      creancesOuvertesFcfa: 0,
      creancesRetard: 0,
      nbOperations: 10,
      semainesActives: 4,
    },
  },
  {
    id: "BF-SIM-07",
    nom: "Salimata Kaboré",
    genre: "femme",
    ville: "Ouagadougou",
    zone: "Cissin",
    metier: "services",
    description:
      "Coiffeuse salon. Très régulière, tontine, historique crédit remboursé, candidature solide.",
    profil: {
      ancienneteLabel: "6_10",
      caJourLabel: "15_30k",
      tontine: true,
      tontineCotis: 12_000,
      mobileMoney: "quotidien",
      compte: "oui_actif",
      chargesFixesMensuelles: 30_000,
      saisonnalite: "stable",
      garantieSolidaire: true,
    },
    features: feat({
      anciennete: 4,
      caJourLabel: "15_30k",
      tontine: true,
      tontineAns: 4,
      mobileMoney: 3,
      compte: 2,
      creditHist: 2,
      opsLast30Days: 18,
      salesLast30Fcfa: 520_000,
      expensesLast30Fcfa: 210_000,
      monthlyFixedChargesFcfa: 30_000,
      tontineCotisations30Fcfa: 12_000,
      openDebtsFcfa: 20_000,
      garantieSolidaire: true,
      activeWeeksLast30: 5,
    }),
    cahier: {
      ventesFcfa: 520_000,
      depensesFcfa: 210_000,
      creancesOuvertesFcfa: 20_000,
      creancesRetard: 0,
      nbOperations: 18,
      semainesActives: 5,
    },
  },
  {
    id: "BF-SIM-08",
    nom: "Moussa Diallo",
    genre: "homme",
    ville: "Bobo-Dioulasso",
    zone: "Colma",
    metier: "menuiserie",
    description:
      "Menuisier. Gros projets à crédit client, plusieurs impayés, charges atelier élevées. CA déclaré 30–60 k/j peu cohérent avec le cahier (ventes ~350 k/30 j) — sous-déclaration probable.",
    profil: {
      ancienneteLabel: "3_5",
      caJourLabel: "30_60k",
      tontine: false,
      tontineCotis: 0,
      mobileMoney: "occasionnel",
      compte: "non",
      chargesFixesMensuelles: 55_000,
      saisonnalite: "moderee",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 3,
      caJourLabel: "30_60k",
      mobileMoney: 1,
      opsLast30Days: 9,
      salesLast30Fcfa: 350_000,
      expensesLast30Fcfa: 220_000,
      monthlyFixedChargesFcfa: 55_000,
      openDebtsFcfa: 450_000,
      impayes: 3,
      overdueDebtsCount: 3,
      partCredit: 4,
      saisonnalite: "moderee",
      activeWeeksLast30: 3,
    }),
    cahier: {
      ventesFcfa: 350_000,
      depensesFcfa: 220_000,
      creancesOuvertesFcfa: 450_000,
      creancesRetard: 3,
      nbOperations: 9,
      semainesActives: 3,
    },
  },
  {
    id: "BF-SIM-09",
    nom: "Rasmané Ilboudo",
    genre: "homme",
    ville: "Ouagadougou",
    zone: "Patte d'Oie",
    metier: "commerce",
    description:
      "Boutique pièces détachées. CA élevé, compte bancaire actif, peu de retard.",
    profil: {
      ancienneteLabel: "p10",
      caJourLabel: "60_100k",
      tontine: false,
      tontineCotis: 0,
      mobileMoney: "quotidien",
      compte: "oui_actif",
      chargesFixesMensuelles: 80_000,
      saisonnalite: "stable",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 5,
      caJourLabel: "60_100k",
      mobileMoney: 3,
      compte: 2,
      creditHist: 2,
      opsLast30Days: 30,
      salesLast30Fcfa: 2_100_000,
      expensesLast30Fcfa: 1_400_000,
      monthlyFixedChargesFcfa: 80_000,
      openDebtsFcfa: 95_000,
      partCredit: 2,
      activeWeeksLast30: 5,
    }),
    cahier: {
      ventesFcfa: 2_100_000,
      depensesFcfa: 1_400_000,
      creancesOuvertesFcfa: 95_000,
      creancesRetard: 0,
      nbOperations: 30,
      semainesActives: 5,
    },
  },
  {
    id: "BF-SIM-10",
    nom: "Aïcha Nabé",
    genre: "femme",
    ville: "Ouahigouya",
    zone: "Centre-ville",
    metier: "commerce",
    description:
      "Vendeuse fripes. Débutante, volume faible, activité insuffisante pour éligibilité.",
    profil: {
      ancienneteLabel: "m1",
      caJourLabel: "m5k",
      tontine: false,
      tontineCotis: 0,
      mobileMoney: "jamais",
      compte: "non",
      chargesFixesMensuelles: 8_000,
      saisonnalite: "stable",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 1,
      caJourLabel: "m5k",
      mobileMoney: 0,
      opsLast30Days: 3,
      salesLast30Fcfa: 45_000,
      expensesLast30Fcfa: 20_000,
      monthlyFixedChargesFcfa: 8_000,
      activeWeeksLast30: 2,
      telephone: 1,
    }),
    cahier: {
      ventesFcfa: 45_000,
      depensesFcfa: 20_000,
      creancesOuvertesFcfa: 0,
      creancesRetard: 0,
      nbOperations: 3,
      semainesActives: 2,
    },
  },
  {
    id: "BF-SIM-11",
    nom: "Hamidou Ouattara",
    genre: "homme",
    ville: "Banfora",
    zone: "Marché central",
    metier: "commerce",
    description:
      "Grossiste sucre/huile. Volume élevé, tontine, Orange Money quotidien — profil solide.",
    profil: {
      ancienneteLabel: "6_10",
      caJourLabel: "60_100k",
      tontine: true,
      tontineCotis: 25_000,
      mobileMoney: "quotidien",
      compte: "oui_actif",
      chargesFixesMensuelles: 60_000,
      saisonnalite: "stable",
      garantieSolidaire: true,
    },
    features: feat({
      anciennete: 4,
      caJourLabel: "60_100k",
      tontine: true,
      tontineAns: 4,
      mobileMoney: 3,
      compte: 2,
      creditHist: 2,
      opsLast30Days: 32,
      salesLast30Fcfa: 1_850_000,
      expensesLast30Fcfa: 1_200_000,
      monthlyFixedChargesFcfa: 60_000,
      tontineCotisations30Fcfa: 25_000,
      openDebtsFcfa: 70_000,
      garantieSolidaire: true,
      activeWeeksLast30: 5,
    }),
    cahier: {
      ventesFcfa: 1_850_000,
      depensesFcfa: 1_200_000,
      creancesOuvertesFcfa: 70_000,
      creancesRetard: 0,
      nbOperations: 32,
      semainesActives: 5,
    },
  },
  {
    id: "BF-SIM-12",
    nom: "Clarisse Nikiema",
    genre: "femme",
    ville: "Ouagadougou",
    zone: "Tanghin",
    metier: "restauration",
    description:
      "Vendeuse de tô / beignets. Cahier bien tenu, écart CA déclaré/réel faible.",
    profil: {
      ancienneteLabel: "3_5",
      caJourLabel: "15_30k",
      tontine: true,
      tontineCotis: 7_000,
      mobileMoney: "regulier",
      compte: "non",
      chargesFixesMensuelles: 22_000,
      saisonnalite: "stable",
      garantieSolidaire: false,
    },
    features: feat({
      anciennete: 3,
      caJourLabel: "15_30k",
      tontine: true,
      tontineAns: 2,
      mobileMoney: 2,
      opsLast30Days: 20,
      salesLast30Fcfa: 580_000,
      expensesLast30Fcfa: 310_000,
      monthlyFixedChargesFcfa: 22_000,
      tontineCotisations30Fcfa: 7_000,
      openDebtsFcfa: 15_000,
      activeWeeksLast30: 5,
      creditHist: 1,
    }),
    cahier: {
      ventesFcfa: 580_000,
      depensesFcfa: 310_000,
      creancesOuvertesFcfa: 15_000,
      creancesRetard: 0,
      nbOperations: 20,
      semainesActives: 5,
    },
  },
];

function fmt(n: number): string {
  return new Intl.NumberFormat("fr-FR").format(n);
}

function run() {
  mkdirSync(OUT_DIR, { recursive: true });
  const computedAt = new Date().toISOString();

  const rows = PERSONAS.map((p) => {
    const result = computeNeoScore(p.features);
    const offer = buildOfferAmount(result.score, p.features);
    return {
      ...p,
      score: result.score,
      segment: result.segment,
      eligible: result.eligible,
      threshold: result.threshold,
      criteria: result.criteria,
      dataQuality: result.dataQuality,
      repaymentCapacity: result.repaymentCapacity,
      offer,
      engine: result.engine ?? "heuristic",
    };
  });

  const eligible = rows.filter((r) => r.eligible);
  const bySegment = { A: 0, B: 0, C: 0, D: 0 };
  for (const r of rows) bySegment[r.segment as keyof typeof bySegment]++;

  const avgScore =
    Math.round(rows.reduce((s, r) => s + r.score, 0) / rows.length);

  const payload = {
    meta: {
      title: "TeriyaScore — Simulation solvabilité Burkina Faso",
      version: "1.0",
      generatedAt: computedAt,
      engine: "heuristic (@teriyascore/neoscore)",
      seuilEligibilite: 50,
      nPersonas: rows.length,
      nEligible: eligible.length,
      avgScore,
      bySegment,
    notes: [
      "Données simulées réalistes (FCFA, métiers informels Ouaga/Bobo/secondaires).",
      "Le score n’utilise pas de labels de remboursement réels (ML synthétique hors scope).",
      "Éligibilité = score >= 50 + activité min. (5 ops ou 4 semaines) + capacité >= 50 000 FCFA + retards < 2 + créances <= 120% ventes 30 j.",
    ],
    },
    personas: rows.map((r) => ({
      id: r.id,
      nom: r.nom,
      genre: r.genre,
      ville: r.ville,
      zone: r.zone,
      metier: r.metier,
      description: r.description,
      profil: r.profil,
      cahier: r.cahier,
      score: r.score,
      segment: r.segment,
      eligible: r.eligible,
      criteria: r.criteria,
      dataQuality: r.dataQuality,
      repaymentCapacity: r.repaymentCapacity,
      offer: r.offer,
      warnings: r.dataQuality?.warnings ?? [],
    })),
  };

  const jsonPath = join(OUT_DIR, "neoscore-simulation-burkina.json");
  writeFileSync(jsonPath, JSON.stringify(payload, null, 2), "utf8");

  // CSV résumé
  const csvLines = [
    "id;nom;genre;ville;metier;score;segment;eligible;ventes30j;ops;offreSuggeree;warnings",
    ...payload.personas.map(
      (p) =>
        `${p.id};${p.nom};${p.genre};${p.ville};${p.metier};${p.score};${p.segment};${p.eligible ? "oui" : "non"};${p.cahier.ventesFcfa};${p.cahier.nbOperations};${p.offer.suggestedFcfa};"${(p.warnings ?? []).join(" | ")}"`
    ),
  ];
  writeFileSync(
    join(OUT_DIR, "neoscore-simulation-burkina.csv"),
    csvLines.join("\n"),
    "utf8"
  );

  console.log(`Écrit: ${jsonPath}`);
  console.log(
    `Résumé: ${rows.length} profils · score moyen ${avgScore} · éligibles ${eligible.length}/${rows.length}`
  );
  console.log(
    "Segments:",
    Object.entries(bySegment)
      .map(([k, v]) => `${k}=${v}`)
      .join(" ")
  );
  console.log(
    "Top scores:",
    [...rows]
      .sort((a, b) => b.score - a.score)
      .slice(0, 3)
      .map((r) => `${r.nom} (${r.score}/${r.segment})`)
      .join(" · ")
  );
  console.log(
    "Ex. éligible:",
    eligible[0]
      ? `${eligible[0].nom} → offre ${fmt(eligible[0].offer.suggestedFcfa)} FCFA`
      : "aucun"
  );
}

run();
