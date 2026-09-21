const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const uuid = /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i;
const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
  const authorization = req.headers.get("Authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) return reply(401, { error: "UNAUTHORIZED" });
  const url = Deno.env.get("SUPABASE_URL"), key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return reply(500, { error: "SERVER_CONFIGURATION_ERROR" });
  try {
    const auth = await fetch(`${url}/auth/v1/user`, { headers: { apikey: key, Authorization: authorization }, signal: AbortSignal.timeout(10000) });
    const user = await auth.json();
    if (!auth.ok || !uuid.test(user?.id ?? "")) return reply(401, { error: "UNAUTHORIZED" });
    const body = await req.json();
    const roomId = typeof body?.room_id === "string" ? body.room_id.trim() : "";
    const name = typeof body?.display_name === "string" ? body.display_name.trim().slice(0, 20) : "";
    if (!uuid.test(roomId) || !name) return reply(400, { error: "INVALID_REQUEST" });
    const update = await fetch(`${url}/rest/v1/room_members?room_id=eq.${roomId}&user_id=eq.${user.id}`, {
      method: "PATCH", headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify({ display_name: name }), signal: AbortSignal.timeout(10000),
    });
    const data = await update.json();
    if (!update.ok || !Array.isArray(data) || data.length !== 1) return reply(403, { error: "ROOM_ACCESS_DENIED" });
    return reply(200, { display_name: name });
  } catch { return reply(502, { error: "NETWORK_ERROR" }); }
});
