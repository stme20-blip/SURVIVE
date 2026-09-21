const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuid = /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const codePattern = /^[A-HJ-NP-Z2-9]{6}$/;
function reply(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), { status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });
}

export async function handleRequest(req: Request, env: (key: string) => string | undefined,
  request: typeof fetch = fetch): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) return reply(401, { error: "UNAUTHORIZED" });
  const url = env("SUPABASE_URL");
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(500, { error: "SERVER_CONFIGURATION_ERROR" });
  try {
    // Same authentication contract as create-room; never trust body.user_id.
    const auth = await request(`${url}/auth/v1/user`, {
      headers: { apikey: key, Authorization: authorization }, signal: AbortSignal.timeout(10000),
    });
    if (!auth.ok) return reply(auth.status >= 500 || auth.status === 429 ? 503 : 401,
      { error: auth.status >= 500 || auth.status === 429 ? "AUTH_UNAVAILABLE" : "UNAUTHORIZED" });
    const user = await auth.json();
    if (typeof user?.id !== "string" || !uuid.test(user.id)) return reply(401, { error: "UNAUTHORIZED" });
    let body;
    try { body = await req.json(); } catch { return reply(400, { error: "INVALID_INVITE_CODE" }); }
    const code = typeof body?.invite_code === "string" ? body.invite_code.trim().toUpperCase() : "";
    if (!codePattern.test(code)) return reply(400, { error: "INVALID_INVITE_CODE" });
    const rpc = await request(`${url}/rest/v1/rpc/join_room_by_code`, {
      method: "POST", headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_invite_code: code, p_user_id: user.id }), signal: AbortSignal.timeout(15000),
    });
    const data = await rpc.json();
    if (!rpc.ok) {
      console.error("join-room: RPC failed", { status: rpc.status });
      return reply(500, { error: "JOIN_FAILED" });
    }
    const errors: Record<string, number> = { UNAUTHORIZED: 401, INVALID_INVITE_CODE: 400,
      ROOM_NOT_FOUND: 404, ROOM_CLOSED: 409, ROOM_FULL: 409, EPISODE_NOT_READY: 409 };
    if (data?.error) return reply(errors[data.error] ?? 500,
      { error: Object.hasOwn(errors, data.error) ? data.error : "JOIN_FAILED" });
    if (!data || !uuid.test(data.room_id ?? "") || !uuid.test(data.host_user_id ?? "") ||
      data.invite_code !== code || data.is_host !== (data.host_user_id === user.id) ||
      data.max_players !== 4 || !["lobby", "playing"].includes(data.status) ||
      !["school", "hospital"].includes(data.episode_id) || !Number.isInteger(data.member_count) || data.member_count < 1 || data.member_count > 4) {
      return reply(502, { error: "UNEXPECTED_RESPONSE" });
    }
    return reply(200, { room_id: data.room_id, invite_code: data.invite_code,
      host_user_id: data.host_user_id, is_host: data.is_host, max_players: 4,
      status: data.status, member_count: data.member_count, episode_id: data.episode_id });
  } catch {
    console.error("join-room: upstream request failed");
    return reply(502, { error: "NETWORK_ERROR" });
  }
}

if (typeof Deno !== "undefined") Deno.serve((req: Request) => handleRequest(req, Deno.env.get));
