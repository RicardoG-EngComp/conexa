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
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;

    const userRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: authHeader, apikey: anon },
    });
    if (!userRes.ok) return json({ error: "unauthorized" }, 401);

    const key = Deno.env.get("GIPHY_API_KEY");
    if (!key) return json({ error: "giphy not configured" }, 500);

    const body = await req.json().catch(() => ({}));
    const type = body.type === "stickers" ? "stickers" : "gifs";
    const query = String(body.q ?? "").slice(0, 60).trim();
    const endpoint = query ? "search" : "trending";

    const params = new URLSearchParams({
      api_key: key,
      limit: "24",
      offset: "0",
      rating: "pg-13",
    });
    if (query) params.set("q", query);

    const giphy = await fetch(
      `https://api.giphy.com/v1/${type}/${endpoint}?${params}`,
    );
    if (!giphy.ok) return json({ error: "giphy request failed" }, 502);

    const payload = await giphy.json();
    const results = (payload.data ?? [])
      .map((g: Record<string, any>) => ({
        id: g.id,
        title: g.title ?? "",
        preview: g.images?.fixed_height?.url ?? g.images?.downsized?.url ?? "",
        original: g.images?.original?.url ?? g.images?.downsized?.url ?? "",
      }))
      .filter((g: Record<string, string>) => g.preview && g.original);

    return json({ results });
  } catch {
    return json({ error: "internal error" }, 500);
  }
});
