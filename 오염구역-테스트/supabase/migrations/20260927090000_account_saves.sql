begin;
create table public.account_saves (
 user_id uuid not null references auth.users(id) on delete cascade,
 slot_id text not null check (slot_id ~ '^[A-Za-z0-9_-]{1,100}$'),
 revision bigint not null default 1,
 payload jsonb not null default '{}',
 deleted boolean not null default false,
 updated_at timestamptz not null default now(),
 primary key(user_id, slot_id),
 check (octet_length(payload::text) <= 4194304)
);
alter table public.account_saves enable row level security;
-- No direct table writes: every change goes through compare-and-swap below.
revoke all on public.account_saves from anon, authenticated;

create function public.account_save_sync(
 p_action text, p_slot text default '', p_revision bigint default 0,
 p_payload jsonb default '{}', p_deleted boolean default false
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 owner_id uuid := auth.uid(); s public.account_saves%rowtype; result jsonb;
begin
 if owner_id is null or coalesce((auth.jwt()->>'is_anonymous')::boolean, true)
 or not exists(select 1 from auth.users where id=owner_id and not is_anonymous) then
  raise insufficient_privilege using message='Member login required';
 end if;
 if p_action='list' then
  select coalesce(jsonb_agg(jsonb_build_object('slot_id',slot_id,'revision',revision,'deleted',deleted) order by slot_id),'[]')
  into result from public.account_saves where user_id=owner_id;
  return jsonb_build_object('ok',true,'slots',result);
 end if;
 if p_slot is null or p_slot !~ '^[A-Za-z0-9_-]{1,100}$' then
  raise invalid_parameter_value using message='Invalid slot';
 end if;
 if p_action='read' then
  select * into s from public.account_saves where user_id=owner_id and slot_id=p_slot;
  if not found then return jsonb_build_object('ok',false,'error','NOT_FOUND'); end if;
  return jsonb_build_object('ok',true,'revision',s.revision,'payload',s.payload,'deleted',s.deleted);
 end if;
 if p_action is null or p_action <> 'write' or p_revision is null or p_revision < 0 or p_deleted is null
 or p_payload is null or jsonb_typeof(p_payload) <> 'object'
 or octet_length(p_payload::text) > 4194304 then
  raise invalid_parameter_value using message='Invalid save';
 end if;
 if not p_deleted and (p_payload->>'room_id' is distinct from p_slot
 or jsonb_typeof(p_payload->'game_state') is distinct from 'object'
 or jsonb_typeof(p_payload->'members') is distinct from 'array') then
  raise invalid_parameter_value using message='Invalid room';
 end if;
 -- Serializes writes per user, including concurrent inserts of the same slot.
 perform 1 from auth.users where id=owner_id for update;
 select * into s from public.account_saves where user_id=owner_id and slot_id=p_slot for update;
 if not found then
  if p_revision<>0 then return jsonb_build_object('ok',false,'conflict',true); end if;
  insert into public.account_saves(user_id,slot_id,payload,deleted)
  values(owner_id,p_slot,p_payload,p_deleted) returning * into s;
 elsif s.payload=p_payload and s.deleted=p_deleted then
  -- Idempotent retry after the server committed but the response was lost.
  null;
 elsif s.revision<>p_revision then
  return jsonb_build_object('ok',false,'conflict',true);
 else
  update public.account_saves set payload=p_payload, deleted=p_deleted,
  revision=revision+1, updated_at=now() where user_id=owner_id and slot_id=p_slot returning * into s;
 end if;
 return jsonb_build_object('ok',true,'revision',s.revision);
end $$;
revoke all on function public.account_save_sync(text,text,bigint,jsonb,boolean) from public, anon;
grant execute on function public.account_save_sync(text,text,bigint,jsonb,boolean) to authenticated;
commit;
