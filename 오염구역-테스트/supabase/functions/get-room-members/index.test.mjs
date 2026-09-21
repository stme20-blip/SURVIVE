import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from './index.ts';
const user = '22222222-2222-4222-8222-222222222222';
const room = '33333333-3333-4333-8333-333333333333';
const env = key => ({ SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test-only' })[key];
const req = body => new Request('https://example.invalid', { method: 'POST', headers: { Authorization: 'Bearer user-token' }, body: JSON.stringify(body) });
const json = (data, status = 200) => new Response(JSON.stringify(data), { status });
const members = [{ user_id: '11111111-1111-4111-8111-111111111111', role: 'host', display_name: null }, { user_id: user, role: 'member', display_name: '참가자 2' }];

test('CORS and authentication protect the endpoint', async () => {
  const never = () => { throw Error('must not fetch'); };
  assert.equal((await handleRequest(new Request('https://example.invalid', { method: 'OPTIONS' }), env, never)).status, 204);
  assert.equal((await handleRequest(new Request('https://example.invalid', { method: 'POST' }), env, never)).status, 401);
  assert.equal((await handleRequest(req({ room_id: 'bad' }), env, async () => json({ id: user }))).status, 400);
});
test('only a room member receives a minimal member list', async () => {
  let calls = 0;
  const response = await handleRequest(req({ room_id: room }), env, async url => {
    if (url.endsWith('/user')) return json({ id: user });
    if (++calls === 1) return json([{ user_id: user }]);
    return json(members);
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { members });
});
test('non-member and malformed upstream results do not expose a list', async () => {
  const denied = await handleRequest(req({ room_id: room }), env, async url => url.endsWith('/user') ? json({ id: user }) : json([]));
  assert.deepEqual(await denied.json(), { error: 'ROOM_ACCESS_DENIED' });
  let calls = 0;
  const malformed = await handleRequest(req({ room_id: room }), env, async url => {
    if (url.endsWith('/user')) return json({ id: user });
    if (++calls === 1) return json([{ user_id: user }]);
    return json([{ user_id: user, role: 'attacker' }]);
  });
  assert.equal(malformed.status, 502);
});
