-- Only the trusted Edge Function may pass an authenticated user UUID.
-- No table, RLS policy, or existing host trigger is replaced.
begin;

create function public.join_room_by_code(p_invite_code text, p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text := upper(btrim(p_invite_code));
  v_room public.rooms%rowtype;
  v_count integer;
begin
  if p_user_id is null then
    return jsonb_build_object('error', 'UNAUTHORIZED');
  end if;
  if v_code is null or v_code !~ '^[A-HJ-NP-Z2-9]{6}$' then
    return jsonb_build_object('error', 'INVALID_INVITE_CODE');
  end if;

  -- All joins of the same room serialize on this row until the RPC commits.
  select * into v_room from public.rooms
  where invite_code = v_code for update;
  if not found then
    return jsonb_build_object('error', 'ROOM_NOT_FOUND');
  end if;
  if v_room.status is null or v_room.status not in ('lobby', 'playing') then
    return jsonb_build_object('error', 'ROOM_CLOSED');
  end if;

  select count(*) into v_count from public.room_members where room_id = v_room.id;
  -- Rejoining is allowed even when full; never update an existing host role.
  if not exists (select 1 from public.room_members where room_id = v_room.id and user_id = p_user_id) then
    if v_count >= 4 then
      return jsonb_build_object('error', 'ROOM_FULL');
    end if;
    insert into public.room_members (room_id, user_id, role, display_name)
    values (v_room.id, p_user_id, 'member', '참가자 ' || (v_count + 1)::text);
    v_count := v_count + 1;
  end if;

  return jsonb_build_object(
    'room_id', v_room.id, 'invite_code', v_room.invite_code,
    'host_user_id', v_room.host_user_id, 'is_host', v_room.host_user_id = p_user_id,
    'max_players', 4, 'status', v_room.status, 'member_count', v_count
  );
end;
$$;

revoke all on function public.join_room_by_code(text, uuid) from public, anon, authenticated;
grant execute on function public.join_room_by_code(text, uuid) to service_role;

commit;
