import { createClient } from "npm:@supabase/supabase-js@2";

import { getR2Config, presignGet } from "../_shared/r2.ts";
import { isSafeObjectPath, thumbKey } from "../_shared/media.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_PATHS = 20;
const FEED_URL_TTL = 60 * 60;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "missing auth" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await admin.auth.getUser(
      token,
    );
    if (userError || !userData.user) return json({ error: "invalid auth" }, 401);

    const body = await req.json().catch(() => ({}));
    const rawPaths = Array.isArray(body?.paths) ? body.paths : [];
    const paths = [
      ...new Set(
        rawPaths
          .filter((value: unknown): value is string => typeof value === "string")
          .map((value: string) => value.trim())
          .filter(isSafeObjectPath),
      ),
    ].slice(0, MAX_PATHS);

    if (paths.length === 0) {
      return json({ items: {}, requested: 0, allowed: 0, expiresIn: FEED_URL_TTL });
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });

    const { data: allowedData, error: allowedError } = await userClient.rpc(
      "filter_visible_feed_media",
      { paths },
    );
    if (allowedError) {
      return json({ error: "visibility_check_failed" }, 500);
    }

    const allowed = new Set(
      (Array.isArray(allowedData) ? allowedData : [])
        .filter((value): value is string => typeof value === "string"),
    );

    const allowedPaths = [...allowed];
    const kinds = new Map<string, string>();

    if (allowedPaths.length > 0) {
      const { data: r2Rows, error: r2Error } = await admin
        .from("media_objects")
        .select("object_key, kind")
        .eq("scope", "feed")
        .eq("variant", "full")
        .is("deleted_at", null)
        .in("object_key", allowedPaths);
      if (r2Error) return json({ error: "media_lookup_failed" }, 500);
      for (const row of r2Rows ?? []) {
        if (typeof row.object_key === "string" && typeof row.kind === "string") {
          kinds.set(row.object_key, row.kind);
        }
      }
    }

    const config = getR2Config();
    const items: Record<
      string,
      { full: string; thumb: string; expiresIn: number }
    > = {};

    await Promise.all(
      allowedPaths.map(async (path) => {
        const kind = kinds.get(path);
        if (!kind) return;

        const full = await presignGet(
          config,
          config.buckets.feed,
          path,
          FEED_URL_TTL,
        );
        const thumb = kind === "feed_image"
          ? await presignGet(
            config,
            config.buckets.feed,
            thumbKey(path),
            FEED_URL_TTL,
          )
          : full;

        items[path] = { full, thumb, expiresIn: FEED_URL_TTL };
      }),
    );

    return json({
      items,
      requested: paths.length,
      allowed: Object.keys(items).length,
      expiresIn: FEED_URL_TTL,
    });
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
