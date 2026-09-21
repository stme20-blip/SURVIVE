import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from './index.ts';
const host = '11111111-1111-4111-8111-111111111111';
const member = '22222222-2222-4222-8222-222222222222';
const room = '33333333-3333-4333-8333-333333333333';
const env = key => ({ SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test-only' })[key];
const req = (code = ' k7m4xp ', extra = {}) => new Request('https://example.invalid', {
  method: 'POST', headers: { Authorization: 'Bearer user-token' },
  body: JSON.stringify({ invite_code: code, user_id: host, ...extra }),
});
const json = (data, status = 200) => new Response(JSON.stringify(data), { status });
const success = (user = member, status = 'lobby') => ({ room_id: room, invite_code: 'K7M4XP',
  host_user_id: host, is_host: user === host, max_players: 4, status, member_count: 2, episode_id: 'school' });

test('OPTIONS and unauthorized never reach RPC', async () => {
  const never = () => { throw Error('must not fetch'); };
  const options = await handleRequest(new Request('https://example.invalid', { method: 'OPTIONS' }), env, never);
  assert.equal(options.status, 204);
  assert.equal(options.headers.get('Access-Control-Allow-Origin'), '*');
  assert.equal((await handleRequest(new Request('https://example.invalid', { method: 'POST' }), env, never)).status, 401);
  assert.equal((await handleRequest(req(), env, async () => json({}, 401))).status, 401);
});
test('normalizes code, ignores spoofed identity and permits playing/host reentry', async () => {
  for (const user of [member, host]) for (const status of ['lobby', 'playing']) {
    const response = await handleRequest(req(), env, async (url, options) => {
      if (url.endsWith('/user')) return json({ id: user });
      assert.ok(url.endsWith('/rpc/join_room_by_code'));
      assert.deepEqual(JSON.parse(options.body), { p_invite_code: 'K7M4XP', p_user_id: user });
      return json(success(user, status));
    });
    assert.equal(response.status, 200);
    assert.equal((await response.json()).is_host, user === host);
  }
});
test('rejects invalid alphabet/length without RPC', async () => {
  for (const code of ['', 'K7M4X', 'K7M4XPP', 'I7M4XP', 'O7M4XP', '07M4XP', '17M4XP', null, 123456]) {
    let calls = 0;
    const response = await handleRequest(req(code), env, async () => { calls++; return json({ id: member }); });
    assert.equal(calls, 1);
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error, 'INVALID_INVITE_CODE');
  }
});
test('maps domain and upstream errors without disclosing bodies', async () => {
  for (const [error, status] of [['ROOM_NOT_FOUND', 404], ['ROOM_CLOSED', 409], ['ROOM_FULL', 409]]) {
    const response = await handleRequest(req(), env, async url => url.endsWith('/user') ? json({ id: member }) : json({ error }));
    assert.equal(response.status, status);
    assert.deepEqual(await response.json(), { error });
  }
  const response = await handleRequest(req(), env, async url => url.endsWith('/user') ? json({ id: member }) : json({ secret: 'never return this' }, 500));
  assert.deepEqual(await response.json(), { error: 'JOIN_FAILED' });
});
test('rejects malformed RPC success and network failure', async () => {
  for (const data of [null, { ...success(), is_host: true }, { ...success(), member_count: 5 }]) {
    const response = await handleRequest(req(), env, async url => url.endsWith('/user') ? json({ id: member }) : json(data));
    assert.equal(response.status, 502);
  }
  const response = await handleRequest(req(), env, async () => { throw Error('secret'); });
  assert.deepEqual(await response.json(), { error: 'NETWORK_ERROR' });
});
