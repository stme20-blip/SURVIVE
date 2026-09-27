begin;
do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); guest uuid:=gen_random_uuid(); j jsonb;
 original jsonb:='{"room_id":"slot","game_state":{"checkpoint":"A"},"members":[]}';
 changed jsonb:='{"room_id":"slot","game_state":{"checkpoint":"B"},"members":[]}';
begin
 insert into auth.users(id,is_anonymous) values(a,false),(b,false),(guest,true);
 assert not has_table_privilege('authenticated','public.account_saves','INSERT');
 assert not has_table_privilege('authenticated','public.account_saves','SELECT');
 assert not has_function_privilege('anon','public.account_save_sync(text,text,bigint,jsonb,boolean)','EXECUTE');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'is_anonymous',false)::text,true);
 j:=public.account_save_sync('write','slot',0,original);
 assert j->>'ok'='true' and (j->>'revision')::int=1;
 j:=public.account_save_sync('write','slot',0,original);
 assert (j->>'revision')::int=1, 'Lost-response retry must be idempotent';
 j:=public.account_save_sync('write','slot',1,changed);
 assert (j->>'revision')::int=2;
 j:=public.account_save_sync('write','slot',1,original);
 assert j->>'conflict'='true', 'Second device must not overwrite a newer version';
 j:=public.account_save_sync('read','slot');
 assert j->'payload'->'game_state'->>'checkpoint'='B';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'is_anonymous',false)::text,true);
 assert public.account_save_sync('list')->'slots'='[]'::jsonb, 'Other user must see no slots';
 assert public.account_save_sync('read','slot')->>'error'='NOT_FOUND';
 j:=public.account_save_sync('write','slot',0,original);
 assert (j->>'revision')::int=1, 'Same slot ID must be scoped to the account';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'is_anonymous',false)::text,true);
 j:=public.account_save_sync('write','slot',2,'{}',true);
 assert (j->>'revision')::int=3;
 assert public.account_save_sync('read','slot')->>'deleted'='true';
 assert public.account_save_sync('write','slot',2,original)->>'conflict'='true';
 begin
  perform public.account_save_sync('write','../escape',0,original);
  raise exception 'Invalid slot accepted';
 exception when invalid_parameter_value then null; end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',guest,'is_anonymous',true)::text,true);
 begin
  perform public.account_save_sync('list'); raise exception 'Guest accepted';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claims','{}',true);
 begin
  perform public.account_save_sync('list'); raise exception 'Unauthenticated accepted';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
