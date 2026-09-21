const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuid = /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
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
    const auth = await request(`${url}/auth/v1/user`, { headers: { apikey: key, Authorization: authorization }, signal: AbortSignal.timeout(10000) });
    if (!auth.ok) return reply(auth.status >= 500 || auth.status === 429 ? 503 : 401,
      { error: auth.status >= 500 || auth.status === 429 ? "AUTH_UNAVAILABLE" : "UNAUTHORIZED" });
    const user = await auth.json();
    if (typeof user?.id !== "string" || !uuid.test(user.id)) return reply(401, { error: "UNAUTHORIZED" });
    let body;
    try { body = await req.json(); } catch { return reply(400, { error: "INVALID_ROOM" }); }
    const roomId = typeof body?.room_id === "string" ? body.room_id.trim() : "";
    if (!uuid.test(roomId)) return reply(400, { error: "INVALID_ROOM" });
    const membership = await request(`${url}/rest/v1/room_members?select=user_id&room_id=eq.${roomId}&user_id=eq.${user.id}&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(10000),
    });
    const own = await membership.json();
    if (!membership.ok) return reply(500, { error: "MEMBERS_FAILED" });
    if (!Array.isArray(own) || own.length !== 1) return reply(403, { error: "ROOM_ACCESS_DENIED" });
    const result = await request(`${url}/rest/v1/room_members?select=user_id,role,display_name,joined_at&room_id=eq.${roomId}&order=joined_at.asc,user_id.asc`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(10000),
    });
    const members = await result.json();
    if (!result.ok || !Array.isArray(members) || members.length < 1 || members.length > 4) return reply(500, { error: "MEMBERS_FAILED" });
    if (members.some(m => !uuid.test(m?.user_id ?? "") || !["host", "member"].includes(m?.role))) return reply(502, { error: "UNEXPECTED_RESPONSE" });
    return reply(200, { members });
  } catch {
    console.error("get-room-members: upstream request failed");
    return reply(502, { error: "NETWORK_ERROR" });
  }
}

if (typeof Deno !== "undefined") Deno.serve((req: Request) => handleRequest(req, Deno.env.get));
