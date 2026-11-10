import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type NotificationRow = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  push_attempts: number;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri: string;
};

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
  if (!expectedSecret) {
    return json({ error: "webhook secret not configured" }, 500);
  }
  if (req.headers.get("x-webhook-secret") !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    body = {};
  }

  const record = (body.record ?? {}) as Record<string, unknown>;
  const singleId = typeof record.id === "string"
    ? record.id
    : typeof body.notification_id === "string"
    ? body.notification_id
    : null;

  try {
    if (singleId) {
      const result = await processNotification(singleId);
      return json({ ok: true, processed: 1, result });
    }

    const { data, error } = await admin
      .from("notifications")
      .select("id")
      .is("pushed_at", null)
      .lt("push_attempts", 5)
      .order("created_at", { ascending: true })
      .limit(50);

    if (error) return json({ error: error.message }, 500);

    const results = [];
    for (const row of data ?? []) {
      results.push(await processNotification(row.id));
    }
    return json({ ok: true, processed: results.length, results });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

async function processNotification(id: string) {
  const { data: row, error } = await admin
    .from("notifications")
    .select("id, user_id, type, title, body, data, push_attempts")
    .eq("id", id)
    .maybeSingle<NotificationRow>();

  if (error) throw new Error(error.message);
  if (!row) return { id, skipped: "not found" };
  if (row.push_attempts >= 5) return { id, skipped: "max attempts" };

  const { data: prefs } = await admin
    .from("notification_preferences")
    .select("message_requests, messages, connections, studies")
    .eq("user_id", row.user_id)
    .maybeSingle();

  if (!preferenceEnabled(row.type, prefs)) {
    await markHandled(id, row.push_attempts + 1, "disabled", true);
    return { id, skipped: "disabled" };
  }

  const { data: tokens, error: tokenError } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", row.user_id);

  if (tokenError) throw new Error(tokenError.message);
  if (!tokens || tokens.length === 0) {
    await markHandled(id, row.push_attempts + 1, "no tokens", true);
    return { id, skipped: "no tokens" };
  }

  const serviceAccount = getServiceAccount();
  const accessToken = await getAccessToken(serviceAccount);
  const errors: string[] = [];
  let delivered = 0;

  for (const item of tokens) {
    try {
      await sendFcm(serviceAccount.project_id, accessToken, item.token, row);
      delivered += 1;
    } catch (error) {
      const message = String(error);
      errors.push(message.slice(0, 300));
      if (isInvalidToken(message)) {
        await admin.from("device_tokens").delete().eq("token", item.token);
      }
    }
  }

  const errorText = errors.length ? errors.join(" | ") : null;
  await admin
    .from("notifications")
    .update({
      push_attempts: row.push_attempts + 1,
      push_error: errorText,
      pushed_at: delivered > 0 ? new Date().toISOString() : null,
    })
    .eq("id", id);

  return { id, delivered, failed: errors.length };
}

function preferenceEnabled(
  type: string,
  prefs: Record<string, boolean> | null,
): boolean {
  if (!prefs) return true;
  if (type === "message_request") return prefs.message_requests !== false;
  if (type === "message") return prefs.messages !== false;
  if (type === "connection_request" || type === "connection_accepted") {
    return prefs.connections !== false;
  }
  if (type.startsWith("study_")) return prefs.studies !== false;
  return false;
}

async function markHandled(
  id: string,
  attempts: number,
  reason: string,
  pushed: boolean,
) {
  await admin
    .from("notifications")
    .update({
      push_attempts: attempts,
      push_error: reason,
      pushed_at: pushed ? new Date().toISOString() : null,
    })
    .eq("id", id);
}

function getServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT not configured");
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error("invalid FCM_SERVICE_ACCOUNT");
  }
  return parsed;
}

async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const key = await importPKCS8(account.private_key.replace(/\\n/g, "\n"), "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setAudience(account.token_uri || "https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(
    account.token_uri || "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );

  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(`oauth failed: ${JSON.stringify(data).slice(0, 300)}`);
  }

  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + Number(data.expires_in || 3600),
  };
  return data.access_token;
}

async function sendFcm(
  projectId: string,
  accessToken: string,
  token: string,
  row: NotificationRow,
) {
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(row.data ?? {})) {
    if (value !== null && value !== undefined) {
      data[key] = String(value);
    }
  }
  data.notification_id = row.id;
  data.type = row.type;

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: row.title,
            body: row.body,
          },
          data,
          android: {
            priority: "high",
            notification: {
              channel_id: "conexa_default",
              sound: "default",
              visibility: "PRIVATE",
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`fcm ${response.status}: ${text.slice(0, 300)}`);
  }
}

function isInvalidToken(message: string) {
  return /UNREGISTERED|NOT_FOUND|INVALID_ARGUMENT|registration token/i.test(
    message,
  );
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
