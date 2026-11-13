import { createClient } from "npm:@supabase/supabase-js@2";

import { deleteObject, getR2Config, listPrefix } from "../_shared/r2.ts";

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
    const r2 = getR2Config();
    const prefix = `${userId}/`;

    for (const bucket of [r2.buckets.profile, r2.buckets.study]) {
      const keys = await listPrefix(r2, bucket, prefix);
      for (let i = 0; i < keys.length; i += 20) {
        const chunk = keys.slice(i, i + 20);
        const results = await Promise.all(
          chunk.map((key) => deleteObject(r2, bucket, key)),
        );
        const failed = results.find((result) => !result.ok);
        if (failed) {
          throw new Error(`R2 delete failed (${failed.status})`);
        }
      }
    }

    const { error: mediaError } = await admin
      .from("media_objects")
      .delete()
      .eq("owner_id", userId);
    if (mediaError) return json({ error: mediaError.message }, 500);

    for (
      const bucket of [
        "profile-media",
        "study-media",
        "verification-docs",
        "feedback-media",
        "stickers",
      ]
    ) {
      const paths = await listAll(admin, bucket, userId);
      for (let i = 0; i < paths.length; i += 100) {
        const chunk = paths.slice(i, i + 100);
        if (chunk.length > 0) {
          await admin.storage.from(bucket).remove(chunk);
        }
      }
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) return json({ error: deleteError.message }, 500);

    return json({ ok: true });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

async function listAll(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const { data, error } = await admin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error || !data) return [];

  const paths: string[] = [];
  for (const item of data) {
    const full = `${prefix}/${item.name}`;
    if (item.id === null) {
      paths.push(...await listAll(admin, bucket, full));
    } else {
      paths.push(full);
    }
  }
  return paths;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
