import {
  copyObject,
  deleteObject,
  getR2BackupConfig,
  listPrefix,
} from "../_shared/r2.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-backup-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const RETENTION_DAYS = 7;
const MAX_OBJECTS = 2000;
const COPY_CONCURRENCY = 10;
const DELETE_CONCURRENCY = 20;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const expected = Deno.env.get("MEDIA_BACKUP_SECRET")?.trim() ?? "";
  const received = req.headers.get("x-backup-secret")?.trim() ?? "";
  if (!expected || !safeEqual(expected, received)) {
    return json({ error: "unauthorized" }, 401);
  }

  try {
    const config = getR2BackupConfig();
    const date = new Date().toISOString().slice(0, 10);
    const sources = [
      ["profile", config.buckets.profile],
      ["study", config.buckets.study],
    ] as const;

    let copied = 0;
    let failed = 0;
    let total = 0;

    for (const [scope, bucket] of sources) {
      const keys = await listPrefix(config, bucket, "");
      total += keys.length;
      if (total > MAX_OBJECTS) {
        return json({
          ok: false,
          error: "backup_excede_limite",
          limit: MAX_OBJECTS,
          total,
        }, 413);
      }

      for (let i = 0; i < keys.length; i += COPY_CONCURRENCY) {
        const chunk = keys.slice(i, i + COPY_CONCURRENCY);
        const results = await Promise.all(
          chunk.map(async (key) => {
            const dest = `snapshots/${date}/${scope}/${key}`;
            const response = await copyObject(
              config,
              bucket,
              key,
              config.buckets.backup,
              dest,
            );
            return response.ok;
          }),
        );
        for (const ok of results) {
          if (ok) copied++;
          else failed++;
        }
      }
    }

    let removedSnapshots = 0;
    let removedObjects = 0;

    if (failed === 0) {
      const cutoff = new Date(
        Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000,
      ).toISOString().slice(0, 10);
      const backupKeys = await listPrefix(
        config,
        config.buckets.backup,
        "snapshots/",
      );
      const oldDates = new Set<string>();

      for (const key of backupKeys) {
        const match = key.match(/^snapshots\/(\d{4}-\d{2}-\d{2})\//);
        if (match && match[1] < cutoff) oldDates.add(match[1]);
      }

      for (const oldDate of oldDates) {
        const prefix = `snapshots/${oldDate}/`;
        const keys = backupKeys.filter((key) => key.startsWith(prefix));
        for (let i = 0; i < keys.length; i += DELETE_CONCURRENCY) {
          const chunk = keys.slice(i, i + DELETE_CONCURRENCY);
          const results = await Promise.all(
            chunk.map((key) =>
              deleteObject(config, config.buckets.backup, key)
            ),
          );
          removedObjects += results.filter((response) => response.ok).length;
        }
        removedSnapshots++;
      }
    }

    return json({
      ok: failed === 0,
      date,
      copied,
      failed,
      total,
      removedSnapshots,
      removedObjects,
      retentionDays: RETENTION_DAYS,
    }, failed === 0 ? 200 : 500);
  } catch (error) {
    return json({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
