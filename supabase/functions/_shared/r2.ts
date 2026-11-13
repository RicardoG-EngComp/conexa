import { AwsClient } from "npm:aws4fetch@1.0.20";

export interface R2Config {
  client: AwsClient;
  endpoint: string;
  buckets: {
    profile: string;
    study: string;
    test: string;
    backup: string;
  };
}

export function getR2Config(): R2Config {
  const accountId = Deno.env.get("R2_ACCOUNT_ID")?.trim() ?? "";
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID")?.trim() ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY")?.trim() ?? "";
  const testBucket = Deno.env.get("R2_BUCKET_TEST")?.trim() ?? "conexa-test";

  const missing = [
    ["R2_ACCOUNT_ID", accountId],
    ["R2_ACCESS_KEY_ID", accessKeyId],
    ["R2_SECRET_ACCESS_KEY", secretAccessKey],
    ["R2_BUCKET_TEST", testBucket],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(`R2 nao configurado: faltam ${missing.join(", ")}`);
  }

  const endpoint = (
    Deno.env.get("R2_ENDPOINT")?.trim() ||
    `https://${accountId}.r2.cloudflarestorage.com`
  ).replace(/\/+$/, "");

  const client = new AwsClient({
    accessKeyId,
    secretAccessKey,
    service: "s3",
    region: "auto",
  });

  return {
    client,
    endpoint,
    buckets: {
      profile: Deno.env.get("R2_BUCKET_PROFILE")?.trim() || "conexa-profile",
      study: Deno.env.get("R2_BUCKET_STUDY")?.trim() || "conexa-study",
      test: testBucket,
      backup: Deno.env.get("R2_BUCKET_BACKUP")?.trim() || "conexa-backup",
    },
  };
}

export function getR2BackupConfig(): R2Config {
  const base = getR2Config();
  const accessKeyId = Deno.env.get("R2_BACKUP_ACCESS_KEY_ID")?.trim() ?? "";
  const secretAccessKey = Deno.env.get("R2_BACKUP_SECRET_ACCESS_KEY")?.trim() ??
    "";

  if (!accessKeyId || !secretAccessKey) {
    throw new Error(
      "R2 backup nao configurado: faltam R2_BACKUP_ACCESS_KEY_ID/R2_BACKUP_SECRET_ACCESS_KEY",
    );
  }

  return {
    ...base,
    client: new AwsClient({
      accessKeyId,
      secretAccessKey,
      service: "s3",
      region: "auto",
    }),
  };
}

export function r2Url(endpoint: string, bucket: string, key: string): string {
  const encodedKey = key.split("/").map(encodeURIComponent).join("/");
  return `${endpoint.replace(/\/+$/, "")}/${encodeURIComponent(bucket)}/${encodedKey}`;
}

export async function putObject(
  config: R2Config,
  bucket: string,
  key: string,
  body: BodyInit,
  contentType: string,
): Promise<Response> {
  return await config.client.fetch(r2Url(config.endpoint, bucket, key), {
    method: "PUT",
    body,
    headers: { "Content-Type": contentType },
  });
}

export async function deleteObject(
  config: R2Config,
  bucket: string,
  key: string,
): Promise<Response> {
  return await config.client.fetch(r2Url(config.endpoint, bucket, key), {
    method: "DELETE",
  });
}

export async function copyObject(
  config: R2Config,
  sourceBucket: string,
  sourceKey: string,
  destBucket: string,
  destKey: string,
): Promise<Response> {
  const source = `/${encodeURIComponent(sourceBucket)}/${
    sourceKey.split("/").map(encodeURIComponent).join("/")
  }`;

  return await config.client.fetch(r2Url(config.endpoint, destBucket, destKey), {
    method: "PUT",
    headers: { "x-amz-copy-source": source },
  });
}

export async function listPrefix(
  config: R2Config,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const keys: string[] = [];
  let continuation: string | null = null;

  do {
    const url = new URL(`${config.endpoint}/${encodeURIComponent(bucket)}`);
    url.searchParams.set("list-type", "2");
    url.searchParams.set("prefix", prefix);
    if (continuation) {
      url.searchParams.set("continuation-token", continuation);
    }

    const response = await config.client.fetch(url.toString(), {
      method: "GET",
    });
    if (!response.ok) {
      throw new Error(
        `R2 list failed (${response.status}): ${
          (await response.text()).slice(0, 200)
        }`,
      );
    }

    const xml = await response.text();
    for (const match of xml.matchAll(/<Key>([\s\S]*?)<\/Key>/g)) {
      keys.push(decodeXml(match[1]));
    }

    const next = xml.match(
      /<NextContinuationToken>([\s\S]*?)<\/NextContinuationToken>/,
    );
    continuation = next ? decodeXml(next[1]) : null;
  } while (continuation);

  return keys;
}

export function decodeXml(value: string): string {
  return value
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

export async function presignGet(
  config: R2Config,
  bucket: string,
  key: string,
  expiresInSeconds = 3600,
): Promise<string> {
  const expires = Math.min(Math.max(expiresInSeconds, 1), 604800);
  const url = new URL(r2Url(config.endpoint, bucket, key));
  url.searchParams.set("X-Amz-Expires", String(expires));

  const signed = await config.client.sign(
    new Request(url, { method: "GET" }),
    { aws: { signQuery: true } },
  );

  return signed.url.toString();
}
