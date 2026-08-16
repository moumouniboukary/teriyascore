import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { computeAgentScorecard } from "../src/agent-scorecard.js";
import type { AgentScoreInput } from "@teriyascore/shared";

const base = (over: Partial<AgentScoreInput> = {}): AgentScoreInput => ({
  clientNom: "Aminata Ouédraogo",
  clientTelephone: "+22670000000",
  clientConnu: false,
  secteurActivite: "commerce",
  tailleMenage: 4,
  incidentsPaiement: 0,
  regulariteDepots: 0,
  ancienneteCompteMois: 0,
  remboursementsAnterieurs: 0,
  ancienneteActiviteAns: 4,
  tontine: true,
  tontineAns: 3,
  nbGarants: 2,
  ancienneteCoopAns: 2,
  saisonnalite: "stable",
  actifTerrain: true,
  actifBetail: false,
  actifMateriel: true,
  revenuMensuelFcfa: 150_000,
  chargesMensuellesFcfa: 40_000,
  montantDemandeFcfa: 100_000,
  dureeMois: 3,
  ...over,
});

describe("computeAgentScorecard", () => {
  it("produit un score 300–850, 3 drivers, risque et reco graduée", () => {
    const r = computeAgentScorecard(base());
    assert.ok(r.score >= 300 && r.score <= 850);
    assert.equal(r.drivers.length, 3);
    assert.ok(["faible", "modere", "eleve"].includes(r.riskCategory));
    assert.ok(
      ["recommande", "analyse_complementaire", "a_reexaminer"].includes(
        r.recommendation
      )
    );
    assert.ok(r.chargeRate >= 0);
    assert.ok(r.montantSoutenableFcfa >= 0);
  });

  it("recommande un dossier solide avec charge soutenable", () => {
    const r = computeAgentScorecard(
      base({
        clientConnu: true,
        regulariteDepots: 3,
        ancienneteCompteMois: 24,
        remboursementsAnterieurs: 2,
        incidentsPaiement: 0,
        ancienneteActiviteAns: 6,
        nbGarants: 2,
        montantDemandeFcfa: 80_000,
        revenuMensuelFcfa: 200_000,
        chargesMensuellesFcfa: 30_000,
      })
    );
    assert.ok(r.score >= 685);
    assert.equal(r.recommendation, "recommande");
    assert.equal(r.riskCategory, "faible");
    assert.ok(r.chargeRate <= 0.35);
  });

  it("propose un montant soutenable quand la demande est trop élevée", () => {
    const r = computeAgentScorecard(
      base({
        revenuMensuelFcfa: 80_000,
        chargesMensuellesFcfa: 20_000,
        montantDemandeFcfa: 500_000,
      })
    );
    assert.ok(r.montantSoutenableFcfa < 500_000);
    assert.ok(r.chargeRate > 0.35);
    assert.notEqual(r.recommendation, "recommande");
  });

  it("score un primo-demandeur via proxies (sans historique)", () => {
    const r = computeAgentScorecard(
      base({
        clientConnu: false,
        regulariteDepots: 0,
        ancienneteCompteMois: 0,
        remboursementsAnterieurs: 0,
        ancienneteActiviteAns: 5,
        tontine: true,
        tontineAns: 4,
        nbGarants: 2,
        actifTerrain: true,
        montantDemandeFcfa: 60_000,
        revenuMensuelFcfa: 180_000,
        chargesMensuellesFcfa: 30_000,
      })
    );
    assert.ok(r.score >= 520);
    assert.ok(r.drivers.some((d) => d.key === "tontine" || d.key === "garants"));
    assert.ok(!r.drivers.some((d) => d.key === "regulariteDepots"));
  });
});
