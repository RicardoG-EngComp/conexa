import { createClient } from "npm:@supabase/supabase-js@2";
import { importJWK, jwtVerify } from "npm:jose@5";

// Chave publica do QR da CIN (PROD), extraida do app oficial
// identidade-nacional 1.19.0 (ENVIRONMENTS[*].publicKeyJWT).
const CIN_PUBLIC_JWK = {
  kty: "EC",
  crv: "P-521",
  x: "ADmN2eus6YfvziHBVuc6cKlzWQ4w_hz1sU0c4qYxFFpNVnEw_d6PO_QVl0OQxMo7WxC0okYDqCVtEl9yoRUA3RLK",
  y: "AFc1lVJVmpLHNNnqXUmFToa6u2l9c_eOOdF6TqAj7chdGtKyqJQAFTWBzVrDQzUj7A4gWE8O3-q-sMm3EnQR3v7O",
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing auth" }, 401);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await supabase.auth.getUser(
      token,
    );
    if (userError || !userData.user) return json({ error: "invalid auth" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => null);
    const qr = body?.qr;
    const hasQr = typeof qr === "string" && qr.length >= 10;

    let payload: Record<string, unknown> | null = null;
    let valid = false;
    if (hasQr) {
      try {
        const key = await importJWK(CIN_PUBLIC_JWK, "ES512");
        const result = await jwtVerify(qr, key, { algorithms: ["ES512"] });
        payload = result.payload as Record<string, unknown>;
        valid = payload.iss === "MJSP" && typeof payload.cpf === "string" &&
          typeof payload.dns === "string";
      } catch (_) {
        valid = false;
      }
    }

    let birthDate: string | null = null;
    let ageOk = false;
    if (valid && payload) {
      birthDate = parseBirthDate(String(payload.dns));
      ageOk = isAdult(birthDate);
    }

    const cpfHash = payload && typeof payload.cpf === "string"
      ? await hashCpf(payload.cpf)
      : null;

    const { data: attempt, error: attemptError } = await supabase
      .from("verification_attempts")
      .insert({
        user_id: userId,
        status: "pending",
        method: "document_qr",
        qr_valid: valid,
        age_ok: ageOk,
        birth_date: birthDate,
        cpf_hash: cpfHash,
      })
      .select("id")
      .single();

    if (attemptError) return json({ error: attemptError.message }, 500);

    const { error: profileError } = await supabase
      .from("profiles")
      .update({ verification_status: "pending", cpf_hash: cpfHash })
      .eq("id", userId);

    if (profileError) return json({ error: profileError.message }, 500);

    return json({
      ok: true,
      qrValid: valid,
      ageOk,
      birthDate,
      attemptId: attempt.id,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function parseBirthDate(dns: string): string | null {
  // dns no formato dd/MM/yyyy
  const m = dns.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (!m) return null;
  return `${m[3]}-${m[2]}-${m[1]}`;
}

function isAdult(isoDate: string | null): boolean {
  if (!isoDate) return false;
  const d = new Date(isoDate + "T00:00:00Z");
  if (Number.isNaN(d.getTime())) return false;
  const now = new Date();
  let age = now.getUTCFullYear() - d.getUTCFullYear();
  const monthDiff = now.getUTCMonth() - d.getUTCMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getUTCDate() < d.getUTCDate())) {
    age--;
  }
  return age >= 18;
}

async function hashCpf(cpf: string): Promise<string> {
  const secret = Deno.env.get("CPF_HASH_SECRET") ?? "change-me";
  const data = new TextEncoder().encode(`${secret}:${cpf}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
