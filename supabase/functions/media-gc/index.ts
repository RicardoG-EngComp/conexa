import { createClient } from "npm:@supabase/supabase-js@2";

import { deleteObject, getR2Config } from "../_shared/r2.ts";
import { thumbKey } from "../_shared/media.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-gc-secret, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_OBJECTS = 500;
const GRACE_HOURS = 24;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const expected = (Deno.env.get("MEDIA_GC_SECRET") ??
    Deno.env.get("MEDIA_BACKUP_SECRET") ??
    "").trim();
  const received = (req.headers.get("x-gc-secret") ?? "").trim();
  if (!expected || received !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const since = new Date(
      Date.now() - GRACE_HOURS * 60 * 60 * 1000,
    ).toISOString();
    const config = getR2Config();

    const { data: rows, error } = await admin
      .from("media_objects")
      .select("id, owner_id, scope, kind, object_key")
      .in("scope", ["feed", "chat", "qa"])
      .eq("variant", "full")
      .is("deleted_at", null)
      .lt("created_at", since)
      .limit(MAX_OBJECTS);
    if (error) return json({ error: "db_query_failed" }, 500);

    let deleted = 0;
    let kept = 0;

    for (const row of rows ?? []) {
      const key = String(row.object_key);
      const scope = String(row.scope);

      if (scope === "feed") {
        const { count: postRefs } = await admin
          .from("post_media")
          .select("id", { count: "exact", head: true })
          .eq("object_key", key);
        const { count: scheduledRefs } = await admin
          .from("scheduled_posts")
          .select("id", { count: "exact", head: true })
          .contains("payload", {
            media: [{ path: key }],
          });
        const { count: draftRefs } = await admin
          .from("post_drafts")
          .select("id", { count: "exact", head: true })
          .contains("payload", {
            media: [{ path: key }],
          });
        if (
          (postRefs ?? 0) > 0 ||
          (scheduledRefs ?? 0) > 0 ||
          (draftRefs ?? 0) > 0
        ) {
          kept++;
          continue;
        }
      } else if (scope === "chat") {
        const { count } = await admin
          .from("messages")
          .select("id", { count: "exact", head: true })
          .eq("media_path", key);
        if ((count ?? 0) > 0) {
          kept++;
          continue;
        }
      } else if (scope === "qa") {
        const { count: questionRefs } = await admin
          .from("study_question_attachments")
          .select("id", { count: "exact", head: true })
          .eq("object_key", key);
        const { count: answerRefs } = await admin
          .from("study_answer_attachments")
          .select("id", { count: "exact", head: true })
          .eq("object_key", key);
        if ((questionRefs ?? 0) > 0 || (answerRefs ?? 0) > 0) {
          kept++;
          continue;
        }
      }

      const bucket = scope === "feed"
        ? config.buckets.feed
        : config.buckets.chat;
      const keys = [key, thumbKey(key)];
      const results = await Promise.all(
        keys.map((item) => deleteObject(config, bucket, item)),
      );
      if (results.some((item) => !item.ok && item.status !== 404)) {
        continue;
      }

      await admin
        .from("media_objects")
        .update({ deleted_at: new Date().toISOString() })
        .in("object_key", keys);
      deleted++;
    }

    return json({ scanned: rows?.length ?? 0, deleted, kept });
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
