import { createClient } from "redis";

const CACHE_TTL = 300; // 5 minutes

let client: ReturnType<typeof createClient> | null = null;

async function getClient() {
  if (!client) {
    const redisUrl = process.env.REDIS_URL || "redis://localhost:6379";
    client = createClient({ url: redisUrl });
    client.on("error", (err) => console.warn("Redis error (non-fatal):", err.message));
    try {
      await client.connect();
    } catch {
      client = null;
    }
  }
  return client;
}

export async function getCached(key: string): Promise<any | null> {
  try {
    const c = await getClient();
    if (!c) return null;
    const val = await c.get(key);
    return val ? JSON.parse(val) : null;
  } catch {
    return null;
  }
}

export async function setCached(key: string, value: any): Promise<void> {
  try {
    const c = await getClient();
    if (!c) return;
    await c.set(key, JSON.stringify(value), { EX: CACHE_TTL });
  } catch {
    // Redis unavailable — silently skip caching
  }
}
