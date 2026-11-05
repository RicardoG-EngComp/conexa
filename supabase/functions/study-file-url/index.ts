import { createClient } from "npm:@supabase/supabase-js@2";

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
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const materialId = String(body.material_id ?? "");
    if (!materialId) return json({ error: "material_id required" }, 400);

    const { data: material, error: materialError } = await admin
      .from("study_materials")
      .select("author_id, status, hidden_at, kind, storage_path, external_url")
      .eq("id", materialId)
      .maybeSingle();

    if (materialError) return json({ error: materialError.message }, 500);
    if (!material) return json({ error: "material not found" }, 404);

    const { data: adminRow } = await admin
      .from("admins")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();

    const canView = material.author_id === userId ||
      adminRow !== null ||
      (material.status === "approved" && material.hidden_at === null);

    if (!canView) return json({ error: "forbidden" }, 403);

    if (material.kind === "link") {
      return json({ url: material.external_url });
    }

    if (!material.storage_path) {
      return json({ error: "file missing" }, 404);
    }

    const { data: signed, error: signError } = await admin.storage
      .from("study-media")
      .createSignedUrl(material.storage_path, 3600);

    if (signError || !signed) {
      return json({ error: signError?.message ?? "sign failed" }, 500);
    }

    return json({ url: signed.signedUrl });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
