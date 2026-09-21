begin;
create table public.room_comments (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  author_name text not null check (char_length(author_name) between 1 and 20),
  scene_id text not null default '', scene_title text not null default '', body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index room_comments_room_created_idx on public.room_comments(room_id, created_at, id);
alter table public.room_comments enable row level security;
revoke all on public.room_comments from anon, authenticated;
commit;
