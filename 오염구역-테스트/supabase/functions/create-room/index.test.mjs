import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from './index.ts';

const id = '345b7ad5-eb56-44cf-8c36-5573488a378a';
const env = key => ({ SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test-only' })[key];
const req = () => new Request('https://example.invalid', { method: 'POST', headers: { Authorization: 'Bearer fake-user-token' }, body: JSON.stringify({ host_user_id: 'attacker', max_players: 99, display_name: '테스트', episode_id: 'school' }) });
const json = (data, status = 200) => new Response(JSON.stringify(data), { status });

test('CORS and missing authentication never reach DB', async () => {
  const never = () => { throw Error('must not fetch'); };
  assert.equal((await handleRequest(new Request('https://example.invalid', { method: 'OPTIONS' }), env, never)).status, 204);
  assert.equal((await handleRequest(new Request('https://example.invalid', { method: 'POST' }), env, never)).status, 401);
  assert.equal((await handleRequest(req(), env, async () => json({}, 401))).status, 401);
});
test('trusted host, fixed capacity/status, collision retry, trigger owns membership', async () => {
  let inserts = 0;
  const response = await handleRequest(req(), env, async (url, options) => {
    if (url.endsWith('/auth/v1/user')) return json({ id });
	if (url.includes('/room_members?')) return json([], 200);
    assert.ok(url.includes('/rest/v1/rooms?'));
    const body = JSON.parse(options.body);
    assert.equal(body.host_user_id, id);
    assert.equal(body.max_players, 4);
    assert.equal(body.status, 'lobby');
	assert.equal(body.episode_id, 'school');
    assert.match(body.invite_code, /^[A-HJ-NP-Z2-9]{6}$/);
    if (++inserts === 1) return json({ code: '23505', message: 'rooms_invite_code_key' }, 409);
    return json([{ id, ...body }], 201);
  });
  assert.equal(response.status, 201);
  assert.equal(inserts, 2);
  assert.equal((await response.json()).room_id, id);
});
test('DB failure and collision exhaustion are distinguishable', async () => {
  for (const [error, expected] of [
    [{ code: '42501' }, 'room_creation_failed'],
    [{ code: '23505', message: 'rooms_invite_code_key' }, 'invite_code_exhausted'],
    [{ code: '23505', message: 'room_members_pkey' }, 'room_creation_failed'],
  ]) {
    let inserts = 0;
    const response = await handleRequest(req(), env, async url => {
      if (url.endsWith('/user')) return json({ id });
      inserts++;
      return json(error, 409);
    });
    assert.equal((await response.json()).error, expected);
    assert.equal(inserts, expected === 'invite_code_exhausted' ? 5 : 1);
  }
});
test('configuration and network failures return safe JSON', async () => {
  assert.equal((await (await handleRequest(req(), () => undefined)).json()).error, 'server_configuration_error');
  const response = await handleRequest(req(), env, async () => { throw Error('sensitive upstream detail'); });
  assert.equal((await response.json()).error, 'upstream_failure');
});
