import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });
    const userClient = createClient(url, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
    } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { data: adminRow } = await admin
      .from("admins")
      .select("user_id")
      .eq("user_id", user.id)
      .maybeSingle();
    if (!adminRow) return json({ error: "forbidden" }, 403);

    const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
    if (!token) return json({ error: "telegram not configured" }, 500);

    const body = await req.json().catch(() => ({}));
    let pack = String(body.pack ?? "").trim();
    if (!pack) return json({ error: "pack required" }, 400);
    const match = pack.match(/t\.me\/addstickers\/([A-Za-z0-9_]+)/);
    if (match) pack = match[1];
    if (!/^[A-Za-z0-9_]{1,64}$/.test(pack)) {
      return json({ error: "invalid pack name" }, 400);
    }

    const callApi = async (
      method: string,
      params?: Record<string, string>,
    ) => {
      const query = params ? `?${new URLSearchParams(params)}` : "";
      const res = await fetch(
        `https://api.telegram.org/bot${token}/${method}${query}`,
      );
      return await res.json();
    };

    const set = await callApi("getStickerSet", { name: pack });
    if (!set.ok) return json({ error: "pack not found" }, 404);

    const result = set.result;
    if (result.is_animated || result.is_video) {
      return json({ error: "animated_or_video_unsupported" }, 400);
    }

    const setName = String(result.name);
    const existing = await admin
      .from("sticker_packs")
      .select("id")
      .eq("name", setName)
      .eq("source", "telegram")
      .maybeSingle();

    let packId = existing.data?.id as string | undefined;
    if (!packId) {
      const { data, error } = await admin
        .from("sticker_packs")
        .insert({ name: setName, is_public: true, source: "telegram" })
        .select("id")
        .single();
      if (error) throw error;
      packId = data.id as string;
    }

    await admin.from("stickers").delete().eq("pack_id", packId);

    let imported = 0;
    const rows: Record<string, unknown>[] = [];

    for (const sticker of result.stickers) {
      if (sticker.is_animated || sticker.is_video) continue;

      const file = await callApi("getFile", { file_id: sticker.file_id });
      if (!file.ok) continue;

      const filePath = file.result.file_path as string;
      const bin = await fetch(
        `https://api.telegram.org/file/bot${token}/${filePath}`,
      );
      if (!bin.ok) continue;

      const bytes = new Uint8Array(await bin.arrayBuffer());
      const storagePath = `global/${setName}/${sticker.file_unique_id}.webp`;
      const upload = await admin.storage
        .from("stickers")
        .upload(storagePath, bytes, {
          contentType: "image/webp",
          upsert: true,
        });
      if (upload.error) continue;

      rows.push({
        pack_id: packId,
        image_path: storagePath,
        emoji: sticker.emoji ?? null,
        sort_order: imported,
      });
      imported++;
    }

    if (rows.length > 0) {
      const { error } = await admin.from("stickers").insert(rows);
      if (error) throw error;
    }

    return json({ pack: setName, imported });
  } catch {
    return json({ error: "internal error" }, 500);
  }
});
