import { createClient } from "npm:@supabase/supabase-js@2";

import { deleteObject, getR2Config } from "../_shared/r2.ts";
import { isSafeObjectPath, thumbKey } from "../_shared/media.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_PATHS = 20;

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
    const body = await req.json().catch(() => ({}));
    const scope = body?.scope === "study" ? "study" : "profile";
    const rawPaths = Array.isArray(body?.paths) ? body.paths : [];

    const paths = [
      ...new Set(
        rawPaths
          .filter((value: unknown): value is string => typeof value === "string")
          .map((value: string) => value.trim())
          .filter((value: string) =>
            isSafeObjectPath(value) && value.startsWith(`${userId}/`)
          ),
      ),
    ].slice(0, MAX_PATHS);

    if (paths.length === 0) {
      return json({ deleted: 0, keys: [] });
    }

    const keys = [
      ...new Set(paths.flatMap((path) => [path, thumbKey(path)])),
    ];

    const config = getR2Config();
    const bucket = scope === "study"
      ? config.buckets.study
      : config.buckets.profile;

    const results = await Promise.all(
      keys.map(async (key) => {
        const response = await deleteObject(config, bucket, key);
        return { key, ok: response.ok, status: response.status };
      }),
    );

    const failed = results.filter((result) => !result.ok);
    if (failed.length > 0) {
      return json({
        error: "r2_delete_failed",
        failed: failed.slice(0, 5),
      }, 502);
    }

    const { error: dbError } = await admin
      .from("media_objects")
      .update({ deleted_at: new Date().toISOString() })
      .eq("owner_id", userId)
      .in("object_key", keys);

    if (dbError) return json({ error: "db_update_failed" }, 500);

    return json({ deleted: keys.length, keys });
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
