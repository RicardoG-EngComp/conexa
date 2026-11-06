const SHEET_ID = "1QyZtZA7oQxoRrCEtQ8M378Edfa5vRwjKzuO1dYh0jMs";
const SHEET_NAME = "Site";

const CAMPUSES = ["Viçosa", "Florestal", "Rio Paranaíba"];
const GENDERS = [
  "Mulher cis",
  "Mulher trans",
  "Homem cis",
  "Homem trans",
  "Pessoa não binária",
  "Outro",
  "Prefiro não informar"
];

function doPost(e) {
  try {
    const p = (e && e.parameter) || {};

    if ((p.website || "").trim()) {
      return page("Inscrição recebida.");
    }

    const name = (p.name || "").trim();
    const ufvEmail = (p.ufv_email || "").trim().toLowerCase();
    const gmail = (p.gmail || "").trim().toLowerCase();
    const course = (p.course || "").trim();
    const campus = (p.campus || "").trim();
    const gender = (p.gender || "").trim();
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const ufvPattern = /^[^\s@]+@(alunos\.ufv\.br|ufv\.br)$/;

    if (!name || !course) return page("Preencha nome e curso.");
    if (!ufvPattern.test(ufvEmail)) return page("Email UFV inválido.");
    if (!emailPattern.test(gmail)) return page("Conta Google inválida.");
    if (CAMPUSES.indexOf(campus) < 0) return page("Campus inválido.");
    if (GENDERS.indexOf(gender) < 0) return page("Gênero inválido.");
    if (
      p.age !== "true" ||
      p.android !== "true" ||
      p.four_weeks !== "true"
    ) {
      return page("Requisitos do beta não confirmados.");
    }
    if (
      p.consent_independent !== "true" ||
      p.consent_firebase !== "true" ||
      p.consent_privacy !== "true"
    ) {
      return page("Consentimentos não aceitos.");
    }

    const sheet = getSheet();
    const existing = sheet.getLastRow() > 1
      ? sheet.getRange(2, 3, sheet.getLastRow() - 1, 1).getValues()
      : [];
    const already = existing.some(function (row) {
      return String(row[0] || "").trim().toLowerCase() === ufvEmail;
    });
    if (already) {
      return page("Inscrição já recebida para este email UFV.");
    }

    sheet.appendRow([
      new Date(),
      name,
      ufvEmail,
      gmail,
      course,
      campus,
      gender,
      (p.how_heard || "").trim(),
      (p.difficulty || "").trim(),
      "Sim",
      "Sim",
      "Sim",
      "Sim",
      "Sim",
      "Sim"
    ]);

    return page(
      "Inscrição recebida. A seleção considera a ordem de resposta e o equilíbrio da amostra."
    );
  } catch (error) {
    return page("Não foi possível registrar a inscrição. Tente novamente.");
  }
}

function getSheet() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow([
      "Data",
      "Nome",
      "Email UFV",
      "Conta Google",
      "Curso",
      "Campus",
      "Gênero",
      "Como soube",
      "Dificuldade",
      "18+",
      "Android",
      "4 semanas",
      "Consentimento independente",
      "Consentimento Firebase",
      "Consentimento privacidade"
    ]);
  }
  return sheet;
}

function page(message) {
  return HtmlService.createHtmlOutput(
    "<!DOCTYPE html><html><body style=\"font-family:system-ui,sans-serif;padding:16px;color:#14130f\">" +
      "<p>" + message + "</p>" +
      "</body></html>"
  );
}
