/**
 * Génère le PDF des données simulées NeoScore (Burkina Faso).
 * Usage: node scripts/generate-simulation-pdf.mjs
 */
import PDFDocument from "pdfkit";
import {
  createWriteStream,
  readFileSync,
  writeFileSync,
  existsSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const JSON_PATH = join(
  ROOT,
  "docs/simulations/neoscore-simulation-burkina.json"
);
const PDF_PATH = join(
  ROOT,
  "docs/simulations/TeriyaScore_Rapport_Solvabilite_Burkina.pdf"
);
const TXT_PATH = join(
  ROOT,
  "docs/simulations/TeriyaScore_Rapport_Solvabilite_Burkina.txt"
);

const METIER_LABEL = {
  commerce: "Commerce",
  mecanique: "Mécanique",
  restauration: "Restauration",
  transport: "Transport",
  artisanat: "Artisanat",
  agriculture: "Agriculture",
  services: "Services",
  menuiserie: "Menuiserie",
};

/** Helvetica ne gère pas l’espace fine / NBSP français → espaces normales. */
function fmt(n) {
  const v = Math.round(Number(n) || 0);
  return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

function metierLabel(m) {
  return METIER_LABEL[m] ?? m;
}

function eligibilityReason(p) {
  if (p.eligible) return "Éligible";
  const reasons = [];
  if ((p.score ?? 0) < 50) reasons.push("score < 50");
  if (p.dataQuality && !p.dataQuality.minActivityMet) {
    reasons.push("activité insuffisante");
  }
  if ((p.cahier?.creancesRetard ?? 0) >= 2) reasons.push("retards >= 2");
  if ((p.features?.impayes ?? p.cahier?.creancesRetard ?? 0) >= 3) {
    // covered by retards often
  }
  if ((p.cahier?.creancesOuvertesFcfa ?? 0) > (p.cahier?.ventesFcfa ?? 0) * 1.2) {
    reasons.push("créances > 120% ventes");
  }
  if ((p.repaymentCapacity?.maxPrincipalFcfa ?? 0) < 50_000) {
    reasons.push("capacité < 50 000");
  }
  return reasons.length ? reasons.join(" ; ") : "seuils non atteints";
}

function drawHeader(doc, title, subtitle) {
  doc
    .fillColor("#0B3D2E")
    .fontSize(16)
    .font("Helvetica-Bold")
    .text(title, { align: "left" });
  doc.moveDown(0.25);
  doc.fillColor("#555555").fontSize(9).font("Helvetica").text(subtitle);
  doc.moveDown(0.45);
  doc
    .strokeColor("#C4A35A")
    .lineWidth(1.5)
    .moveTo(50, doc.y)
    .lineTo(545, doc.y)
    .stroke();
  doc.moveDown(0.7);
}

function ensureSpace(doc, needed = 80) {
  if (doc.y + needed > doc.page.height - 52) {
    doc.addPage();
    return true;
  }
  return false;
}

function drawTable(doc, personas) {
  const cols = [
    { key: "id", label: "ID", x: 50, w: 28 },
    { key: "nom", label: "Nom", x: 78, w: 108 },
    { key: "ville", label: "Ville", x: 186, w: 78 },
    { key: "metier", label: "Métier", x: 264, w: 72 },
    { key: "score", label: "Score", x: 336, w: 36 },
    { key: "seg", label: "Seg.", x: 372, w: 28 },
    { key: "elig", label: "Élig.", x: 400, w: 32 },
    { key: "motif", label: "Motif / offre", x: 432, w: 113 },
  ];

  const rowH = 16;
  const headerY = doc.y;

  doc.rect(50, headerY, 495, rowH).fill("#0B3D2E");
  doc.fillColor("#FFFFFF").font("Helvetica-Bold").fontSize(7.5);
  for (const c of cols) {
    doc.text(c.label, c.x + 2, headerY + 4, {
      width: c.w - 4,
      lineBreak: false,
    });
  }
  doc.y = headerY + rowH;

  personas.forEach((p, idx) => {
    ensureSpace(doc, rowH + 4);
    const y = doc.y;
    if (idx % 2 === 0) {
      doc.rect(50, y, 495, rowH).fill("#F4F7F5");
    }
    const offerTxt = p.eligible
      ? `${fmt(p.offer?.suggestedFcfa)} F`
      : eligibilityReason(p);
    const cells = {
      id: p.id.replace("BF-SIM-", ""),
      nom: p.nom.length > 18 ? p.nom.slice(0, 16) + ".." : p.nom,
      ville: p.ville.length > 13 ? p.ville.slice(0, 11) + ".." : p.ville,
      metier: metierLabel(p.metier),
      score: String(p.score),
      seg: p.segment,
      elig: p.eligible ? "Oui" : "Non",
      motif: offerTxt.length > 28 ? offerTxt.slice(0, 26) + ".." : offerTxt,
    };
    doc.fillColor("#222222").font("Helvetica").fontSize(7);
    for (const c of cols) {
      doc.text(cells[c.key], c.x + 2, y + 4, {
        width: c.w - 4,
        lineBreak: false,
      });
    }
    doc.y = y + rowH;
  });

  doc
    .strokeColor("#CCCCCC")
    .lineWidth(0.5)
    .rect(50, headerY, 495, rowH * (personas.length + 1))
    .stroke();
  doc.moveDown(0.8);
}

function main() {
  if (!existsSync(JSON_PATH)) {
    console.error(
      "JSON manquant. Lancez d'abord: npx tsx scripts/simulate-neoscore-burkina.ts"
    );
    process.exit(1);
  }
  const data = JSON.parse(readFileSync(JSON_PATH, "utf8"));
  const { meta, personas } = data;

  const doc = new PDFDocument({
    size: "A4",
    margins: { top: 46, bottom: 46, left: 50, right: 50 },
    info: {
      Title: meta.title,
      Author: "TeriyaScore",
      Subject: "Simulation NeoScore — données synthétiques Burkina Faso",
    },
  });
  const stream = createWriteStream(PDF_PATH);
  doc.pipe(stream);

  drawHeader(
    doc,
    "TeriyaScore — Simulation de solvabilité",
    `Burkina Faso · secteur informel · ${meta.generatedAt?.slice(0, 10) ?? ""} · moteur heuristique NeoScore`
  );

  doc.fillColor("#111111").fontSize(11).font("Helvetica-Bold").text("1. Objectif");
  doc
    .font("Helvetica")
    .fontSize(9.5)
    .fillColor("#222222")
    .text(
      "Ce document présente 12 profils simulés d'entrepreneurs informels " +
        "(Ouagadougou, Bobo-Dioulasso, Koudougou, Ouahigouya, Banfora), " +
        "calés sur des CA, charges et usages Mobile Money / tontine réalistes en FCFA. " +
        `Le NeoScore (0-100) est calculé avec le moteur heuristique (seuil d'éligibilité crédit : ${meta.seuilEligibilite}/100).`,
      { align: "justify", lineGap: 1.5 }
    );
  doc.moveDown(0.55);

  doc.font("Helvetica-Bold").fontSize(11).fillColor("#111111").text("2. Synthèse");
  doc.font("Helvetica").fontSize(9.5).fillColor("#222222");
  doc.text(`- Profils simulés : ${meta.nPersonas}`);
  doc.text(`- Score moyen : ${meta.avgScore}/100`);
  doc.text(`- Éligibles au crédit : ${meta.nEligible}/${meta.nPersonas}`);
  doc.text(
    `- Segments : A=${meta.bySegment.A}  B=${meta.bySegment.B}  C=${meta.bySegment.C}  D=${meta.bySegment.D}`
  );
  doc.moveDown(0.35);
  doc.fillColor("#555555").fontSize(8.5);
  doc.text(
    "- Données simulées réalistes (FCFA, métiers informels Ouaga / Bobo / villes secondaires)."
  );
  doc.text(
    "- Le score n'utilise pas de labels de remboursement réels (ML hors scope de ce document)."
  );
  doc.text(
    "- Éligibilité = score >= 50 + activité min. (5 ops ou 4 semaines) + capacité >= 50 000 FCFA"
  );
  doc.text(
    "  + pas de retards multiples (>= 2) + créances ouvertes <= 120 % des ventes 30 j."
  );
  doc.moveDown(0.7);

  doc
    .font("Helvetica-Bold")
    .fontSize(11)
    .fillColor("#111111")
    .text("3. Tableau récapitulatif");
  doc.moveDown(0.35);
  drawTable(doc, personas);

  doc.addPage();
  drawHeader(
    doc,
    "4. Fiches personas et NeoScore",
    "Détail cahier 30 jours · critères · offre indicative · motif si refus"
  );

  for (const p of personas) {
    ensureSpace(doc, 132);
    doc
      .fillColor("#0B3D2E")
      .font("Helvetica-Bold")
      .fontSize(10.5)
      .text(`${p.id} — ${p.nom}`);
    doc
      .font("Helvetica")
      .fontSize(8.5)
      .fillColor("#555555")
      .text(
        `${p.genre === "femme" ? "Femme" : "Homme"} · ${metierLabel(p.metier)} · ${p.ville} (${p.zone})`
      );
    doc.fillColor("#222222").fontSize(9).text(p.description, {
      lineGap: 1,
    });
    doc.moveDown(0.2);

    const c = p.criteria ?? {};
    const offer = p.offer ?? {};
    const cap = p.repaymentCapacity ?? {};
    const dq = p.dataQuality ?? {};

    doc
      .fillColor(p.eligible ? "#0B3D2E" : "#8B1E1E")
      .font("Helvetica-Bold")
      .fontSize(9)
      .text(
        `NeoScore ${p.score}/100 · Segment ${p.segment} · ${p.eligible ? "ÉLIGIBLE" : "NON ÉLIGIBLE"}` +
          (p.eligible ? "" : ` (${eligibilityReason(p)})`)
      );

    doc
      .font("Helvetica")
      .fillColor("#333333")
      .fontSize(8.5)
      .text(
        `Critères — Régularité ${Math.round(c.regularite ?? 0)} · Volume ${Math.round(c.volume ?? 0)} · ` +
          `Créances ${Math.round(c.dettes ?? 0)} · Croissance ${Math.round(c.croissance ?? 0)}` +
          (dq.declaredVsActualRatio != null
            ? ` · Ratio CA ${Math.round(Number(dq.declaredVsActualRatio) * 100)}%`
            : "")
      );
    doc.text(
      `Cahier 30 j — Ventes ${fmt(p.cahier.ventesFcfa)} FCFA · Dépenses ${fmt(p.cahier.depensesFcfa)} · ` +
        `Ops ${p.cahier.nbOperations} · Créances ouvertes ${fmt(p.cahier.creancesOuvertesFcfa)} · Retards ${p.cahier.creancesRetard}`
    );
    doc.text(
      `Capacité — Revenu mensuel estimé ${fmt(cap.estimatedMonthlyRevenueFcfa)} FCFA · ` +
        `Mensualité max ${fmt(cap.maxMonthlyPaymentFcfa)} · Principal max ${fmt(cap.maxPrincipalFcfa)}`
    );

    if (p.eligible) {
      doc
        .fillColor("#0B3D2E")
        .text(
          `Offre indicative : ${fmt(offer.suggestedFcfa)} FCFA ` +
            `(min ${fmt(offer.minFcfa)} – max ${fmt(offer.maxFcfa)})`
        );
    } else {
      doc
        .fillColor("#8B1E1E")
        .text(`Offre : non proposée — ${eligibilityReason(p)}.`);
    }

    if (dq.warnings?.length) {
      const clean = dq.warnings.map((w) =>
        w
          .replace(/≥/g, ">=")
          .replace(/≤/g, "<=")
          .replace(/\u202f/g, " ")
          .replace(/\u00a0/g, " ")
      );
      doc.fillColor("#8B5A00").text(`Alertes qualité : ${clean.join(" | ")}`);
    }

    doc.moveDown(0.4);
    doc
      .strokeColor("#E5E5E5")
      .lineWidth(0.8)
      .moveTo(50, doc.y)
      .lineTo(545, doc.y)
      .stroke();
    doc.moveDown(0.45);
  }

  ensureSpace(doc, 110);
  doc
    .font("Helvetica-Bold")
    .fontSize(11)
    .fillColor("#111111")
    .text("5. Lecture pour le pilote");
  doc.font("Helvetica").fontSize(9.5).fillColor("#222222");
  doc.text(
    "- Les profils A/B avec tontine + Mobile Money régulier + cahier dense sont typiquement éligibles."
  );
  doc.text(
    "- Les créances en retard (>= 2), l'activité < 5 opérations / 30 j, ou un stock de créances trop élevé bloquent l'éligibilité."
  );
  doc.text(
    "- Pour un ML de production, remplacer ces simulations par des outcomes réels (remboursé / défaut) issus des IMF."
  );
  doc.moveDown(0.9);
  doc
    .fontSize(8)
    .fillColor("#777777")
    .text(
      "TeriyaScore · Document de simulation — ne constitue pas une décision de crédit. Données fictives à usage démo / calibrage.",
      { align: "center" }
    );

  doc.end();

  const txtLines = [
    meta.title,
    `Genere: ${meta.generatedAt}`,
    `Score moyen: ${meta.avgScore}/100 | Eligibles: ${meta.nEligible}/${meta.nPersonas}`,
    `Segments: A=${meta.bySegment.A} B=${meta.bySegment.B} C=${meta.bySegment.C} D=${meta.bySegment.D}`,
    "",
    "ID\tNom\tScore\tSeg\tElig\tOffre\tVentes30j\tOps\tRetards\tCreances\tRatioCA\tAlertes",
  ];
  for (const p of personas) {
    const alerts = (p.warnings ?? []).join(" | ").replace(/\s+/g, " ");
    txtLines.push(
      [
        p.id,
        p.nom,
        p.score,
        p.segment,
        p.eligible ? "oui" : "non",
        p.offer?.suggestedFcfa ?? 0,
        p.cahier.ventesFcfa,
        p.cahier.nbOperations,
        p.cahier.creancesRetard,
        p.cahier.creancesOuvertesFcfa,
        Number(p.dataQuality?.declaredVsActualRatio ?? 0).toFixed(2),
        alerts || "-",
      ].join("\t")
    );
  }
  writeFileSync(TXT_PATH, txtLines.join("\n"), "utf8");

  return new Promise((resolve, reject) => {
    stream.on("finish", () => {
      console.log(`PDF ecrit : ${PDF_PATH}`);
      console.log(`TXT ecrit : ${TXT_PATH}`);
      resolve();
    });
    stream.on("error", reject);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
