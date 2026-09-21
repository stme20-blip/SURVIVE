// Generates a transaction-local PostgreSQL test. No public tables/functions are changed.
import { readFileSync, writeFileSync } from 'node:fs';
const output = process.argv[2];
if (!output) throw Error('Pass an output SQL path');
const migration = readFileSync(new URL('../migrations/20260921030000_join_room.sql', import.meta.url), 'utf8')
  .replace(/^begin;$/m, '').replace(/^commit;$/m, '').replaceAll('public.', 'pg_temp.');
writeFileSync(output, `begin;
create temporary table rooms (like public.rooms including defaults including constraints including indexes);
create temporary table room_members (like public.room_members including defaults including constraints including indexes);
${migration}
do $$
declare
  h uuid := '11111111-1111-4111-8111-111111111111';
  b uuid := '22222222-2222-4222-8222-222222222222';
  c uuid := '33333333-3333-4333-8333-333333333333';
  d uuid := '44444444-4444-4444-8444-444444444444';
  e uuid := '55555555-5555-4555-8555-555555555555';
  r uuid;
  result jsonb;
begin
  assert not has_function_privilege('authenticated', 'pg_temp.join_room_by_code(text,uuid)', 'execute');
  assert not has_function_privilege('anon', 'pg_temp.join_room_by_code(text,uuid)', 'execute');
  assert has_function_privilege('service_role', 'pg_temp.join_room_by_code(text,uuid)', 'execute');
  insert into pg_temp.rooms(host_user_id,invite_code) values(h,'K7M4XP') returning id into r;
  -- Host fixture stands in for the existing production trigger (not copied onto temp tables).
  insert into pg_temp.room_members(room_id,user_id,role) values(r,h,'host');
  assert pg_temp.join_room_by_code('I7M4XP',b)->>'error' = 'INVALID_INVITE_CODE';
  assert pg_temp.join_room_by_code('AAAAAA',b)->>'error' = 'ROOM_NOT_FOUND';
  assert pg_temp.join_room_by_code('K7M4XP',null)->>'error' = 'UNAUTHORIZED';
  result := pg_temp.join_room_by_code(' k7m4xp ',b);
  assert result->>'is_host' = 'false' and result->>'member_count' = '2';
  assert pg_temp.join_room_by_code('K7M4XP',b)->>'member_count' = '2';
  assert pg_temp.join_room_by_code('K7M4XP',h)->>'is_host' = 'true';
  assert (select role from pg_temp.room_members where user_id=h) = 'host';
  update pg_temp.rooms set status='playing' where id=r;
  assert pg_temp.join_room_by_code('K7M4XP',c)->>'member_count' = '3';
  assert pg_temp.join_room_by_code('K7M4XP',d)->>'member_count' = '4';
  assert pg_temp.join_room_by_code('K7M4XP',e)->>'error' = 'ROOM_FULL';
  assert pg_temp.join_room_by_code('K7M4XP',b)->>'member_count' = '4';
  assert (select count(*) from pg_temp.room_members where room_id=r) = 4;
  update pg_temp.rooms set status='closed' where id=r;
  assert pg_temp.join_room_by_code('K7M4XP',b)->>'error' = 'ROOM_CLOSED';
end;
$$;
select 'JOIN_SQL_CHECK passed' as result;
rollback;
`);
