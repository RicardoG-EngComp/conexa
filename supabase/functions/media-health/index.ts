import { createClient } from "npm:@supabase/supabase-js@2";

import { getR2Config, listPrefix, r2Url } from "../_shared/r2.ts";

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

    const { data: adminRow } = await admin
      .from("admins")
      .select("user_id")
      .eq("user_id", userData.user.id)
      .maybeSingle();
    if (!adminRow) return json({ error: "forbidden" }, 403);

    const config = getR2Config();
    const key = `health/${crypto.randomUUID()}.txt`;
    const payload = `conexa-r2-health ${new Date().toISOString()}`;
    const body = new TextEncoder().encode(payload);
    const url = r2Url(config.endpoint, config.buckets.test, key);

    const putStart = performance.now();
    const put = await config.client.fetch(url, {
      method: "PUT",
      body,
      headers: { "Content-Type": "text/plain" },
    });
    const putMs = Math.round(performance.now() - putStart);
    if (!put.ok) {
      return json({
        ok: false,
        step: "put",
        status: put.status,
        body: (await put.text()).slice(0, 500),
      }, 502);
    }

    const getStart = performance.now();
    const get = await config.client.fetch(url, { method: "GET" });
    const getMs = Math.round(performance.now() - getStart);
    const downloaded = await get.text();
    if (!get.ok) {
      return json({
        ok: false,
        step: "get",
        status: get.status,
        body: downloaded.slice(0, 500),
      }, 502);
    }
    if (downloaded !== payload) {
      return json({ ok: false, step: "get", error: "conteudo divergente" }, 502);
    }

    const deleteStart = performance.now();
    const deleted = await config.client.fetch(url, { method: "DELETE" });
    const deleteMs = Math.round(performance.now() - deleteStart);
    if (!deleted.ok) {
      return json({
        ok: false,
        step: "delete",
        status: deleted.status,
        body: (await deleted.text()).slice(0, 500),
      }, 502);
    }

    const listed = await listPrefix(
      config,
      config.buckets.test,
      "health/",
    );

    return json({
      ok: true,
      bucket: config.buckets.test,
      key,
      bytes: body.length,
      putMs,
      getMs,
      deleteMs,
      remainingHealthObjects: listed.length,
    });
  } catch (error) {
    return json({
      ok: false,
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
