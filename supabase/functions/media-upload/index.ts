import { createClient } from "npm:@supabase/supabase-js@2";

import { deleteObject, getR2Config, putObject } from "../_shared/r2.ts";
import {
  extensionFor,
  isSafeObjectPath,
  isUuid,
  sniffMime,
} from "../_shared/media.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-kind, x-variant, x-asset-id, x-width, x-height",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ONE_MB = 1024 * 1024;
const PROFILE_FULL_MAX = 5 * ONE_MB;
const STUDY_FULL_MAX = 10 * ONE_MB;
const THUMB_MAX = 1 * ONE_MB;
const STUDY_MONTHLY_FILES = 20;
const STUDY_MONTHLY_BYTES = 200 * ONE_MB;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing auth" }, 401);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await admin.auth.getUser(
      token,
    );
    if (userError || !userData.user) return json({ error: "invalid auth" }, 401);

    const userId = userData.user.id;
    const { data: active } = await admin.rpc("is_active_user", {
      uid: userId,
    });
    if (!active) return json({ error: "conta_inativa" }, 403);

    const kind = (req.headers.get("x-kind") ?? "").trim().toLowerCase();
    const variant = (req.headers.get("x-variant") ?? "full")
      .trim()
      .toLowerCase();
    const declaredMime = (req.headers.get("content-type") ?? "")
      .split(";")[0]
      .trim()
      .toLowerCase();
    const assetIdHeader = (req.headers.get("x-asset-id") ?? "").trim();
    const assetId = isUuid(assetIdHeader)
      ? assetIdHeader.toLowerCase()
      : crypto.randomUUID();

    const rule = validateKind(kind, variant, declaredMime);
    if (!rule) return json({ error: "tipo_ou_variante_invalida" }, 400);

    if (rule.scope === "study") {
      const { data: uploader } = await admin
        .from("study_uploaders")
        .select("user_id")
        .eq("user_id", userId)
        .maybeSingle();
      if (!uploader) return json({ error: "nao_uploader" }, 403);
    }

    const declaredLength = Number(req.headers.get("content-length") ?? "0");
    if (Number.isFinite(declaredLength) && declaredLength > rule.maxBytes) {
      return json({ error: "arquivo_muito_grande" }, 413);
    }

    const bytes = new Uint8Array(await req.arrayBuffer());
    if (bytes.byteLength === 0) return json({ error: "arquivo_vazio" }, 400);
    if (bytes.byteLength > rule.maxBytes) {
      return json({ error: "arquivo_muito_grande" }, 413);
    }

    const sniffed = sniffMime(bytes);
    if (!sniffed || sniffed !== declaredMime) {
      return json({ error: "conteudo_nao_confere_com_tipo" }, 415);
    }

    const quotaError = await checkQuota(
      admin,
      userId,
      rule.scope,
      kind,
      variant,
      bytes.byteLength,
    );
    if (quotaError) return json({ error: quotaError }, 409);

    const config = getR2Config();
    const bucket = rule.scope === "profile"
      ? config.buckets.profile
      : config.buckets.study;
    const extension = extensionFor(sniffed);
    if (!extension) return json({ error: "tipo_nao_suportado" }, 415);

    const base = rule.scope === "profile"
      ? `${userId}/${kind}/${assetId}`
      : `${userId}/study/${assetId}`;
    const key = `${base}${variant === "thumb" ? "_t" : ""}.${extension}`;
    if (!isSafeObjectPath(key)) return json({ error: "caminho_invalido" }, 400);

    const uploaded = await putObject(config, bucket, key, bytes, sniffed);
    if (!uploaded.ok) {
      return json({
        error: "r2_upload_failed",
        status: uploaded.status,
        detail: (await uploaded.text()).slice(0, 300),
      }, 502);
    }

    const sha256 = await sha256Hex(bytes);
    const width = positiveInt(req.headers.get("x-width"));
    const height = positiveInt(req.headers.get("x-height"));

    const { error: dbError } = await admin
      .from("media_objects")
      .upsert({
        asset_id: assetId,
        owner_id: userId,
        scope: rule.scope,
        variant,
        kind,
        object_key: key,
        mime_type: sniffed,
        byte_size: bytes.byteLength,
        width,
        height,
        sha256,
        deleted_at: null,
      }, { onConflict: "scope,object_key" });

    if (dbError) {
      await deleteObject(config, bucket, key);
      return json({ error: "db_insert_failed" }, 500);
    }

    return json({
      ok: true,
      bucket,
      key,
      assetId,
      bytes: bytes.byteLength,
      width,
      height,
    });
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

function validateKind(
  kind: string,
  variant: string,
  mime: string,
): { scope: "profile" | "study"; maxBytes: number } | null {
  if (variant !== "full" && variant !== "thumb") return null;

  if (kind === "study_pdf") {
    if (variant !== "full" || mime !== "application/pdf") return null;
    return { scope: "study", maxBytes: STUDY_FULL_MAX };
  }

  if (!["image/jpeg", "image/png", "image/webp"].includes(mime)) return null;

  if (kind === "avatar" || kind === "photo") {
    return {
      scope: "profile",
      maxBytes: variant === "thumb" ? THUMB_MAX : PROFILE_FULL_MAX,
    };
  }

  if (kind === "study_image") {
    return {
      scope: "study",
      maxBytes: variant === "thumb" ? THUMB_MAX : STUDY_FULL_MAX,
    };
  }

  return null;
}

async function checkQuota(
  admin: ReturnType<typeof createClient>,
  userId: string,
  scope: "profile" | "study",
  kind: string,
  variant: string,
  incomingBytes: number,
): Promise<string | null> {
  if (scope === "profile" && variant === "full") {
    const max = kind === "avatar" ? 2 : 7;
    const { count } = await admin
      .from("media_objects")
      .select("asset_id", { count: "exact", head: true })
      .eq("owner_id", userId)
      .eq("scope", "profile")
      .eq("kind", kind)
      .eq("variant", "full")
      .is("deleted_at", null);
    if ((count ?? 0) >= max) return "quota_perfil";
    return null;
  }

  if (scope === "study") {
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    if (variant === "full") {
      const { count } = await admin
        .from("media_objects")
        .select("asset_id", { count: "exact", head: true })
        .eq("owner_id", userId)
        .eq("scope", "study")
        .eq("variant", "full")
        .is("deleted_at", null)
        .gte("created_at", since);
      if ((count ?? 0) >= STUDY_MONTHLY_FILES) return "quota_estudo_arquivos";
    }

    const { data: usage } = await admin
      .from("media_objects")
      .select("byte_size")
      .eq("owner_id", userId)
      .eq("scope", "study")
      .is("deleted_at", null)
      .gte("created_at", since);

    const used = (usage ?? []).reduce(
      (sum, row) => sum + Number(row.byte_size ?? 0),
      0,
    );
    if (used + incomingBytes > STUDY_MONTHLY_BYTES) {
      return "quota_estudo_bytes";
    }
  }

  return null;
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function positiveInt(value: string | null): number | null {
  if (!value) return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
