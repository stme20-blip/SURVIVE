const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function reply(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function inviteCode(): string {
  // Rejection sampling avoids bias when the alphabet does not divide 256.
  let result = "";
  while (result.length < 6) {
    const byte = crypto.getRandomValues(new Uint8Array(1))[0];
    if (byte < Math.floor(256 / alphabet.length) * alphabet.length) {
      result += alphabet[byte % alphabet.length];
    }
  }
  return result;
}

export async function handleRequest(
  req: Request,
  env: (key: string) => string | undefined,
  request: typeof fetch = fetch,
): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) return reply(401, { error: "unauthorized" });
  const url = env("SUPABASE_URL");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(500, { error: "server_configuration_error" });
  try {
    const auth = await request(`${url}/auth/v1/user`, {
      headers: { apikey: key, Authorization: authorization },
      signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return reply(auth.status >= 500 || auth.status === 429 ? 503 : 401,
      { error: auth.status >= 500 || auth.status === 429 ? "auth_unavailable" : "unauthorized" });
    const user = await auth.json();
    if (typeof user.id !== "string" || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(user.id)) {
      return reply(401, { error: "unauthorized" });
    }
    // Deliberately ignore the request body: identity, capacity and status are server-owned.
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = inviteCode();
      const inserted = await request(`${url}/rest/v1/rooms?select=id,invite_code,max_players,status`, {
        method: "POST",
        headers: { apikey: key, Authorization: `Bearer ${key}`,
          "Content-Type": "application/json", Prefer: "return=representation" },
        body: JSON.stringify({ host_user_id: user.id, invite_code: code, max_players: 4, status: "lobby" }),
        signal: AbortSignal.timeout(10000),
      });
      const data = await inserted.json();
      if (inserted.ok) {
        const room = Array.isArray(data) ? data[0] : null;
        if (!room?.id || room.invite_code !== code || room.max_players !== 4 || room.status !== "lobby") {
          return reply(502, { error: "unexpected_response" });
        }
        // The existing database trigger inserts the host member in this transaction.
        return reply(201, { room_id: room.id, invite_code: room.invite_code, max_players: 4, status: "lobby" });
      }
      if (data?.code === "23505" && `${data.message ?? ""} ${data.details ?? ""}`.includes("invite_code")) continue;
      console.error("create-room: insert failed", { status: inserted.status, code: String(data?.code ?? "unknown").slice(0, 10) });
      return reply(500, { error: "room_creation_failed" });
    }
    return reply(503, { error: "invite_code_exhausted" });
  } catch {
    console.error("create-room: upstream request failed");
    return reply(502, { error: "upstream_failure" });
  }
}

// Guard permits isolated Node tests without starting a server or contacting Supabase.
if (typeof Deno !== "undefined") Deno.serve((req: Request) => handleRequest(req, Deno.env.get));
