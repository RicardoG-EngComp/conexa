-- B3: feed social (posts, comentarios, curtidas)
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

alter table public.posts enable row level security;

drop policy if exists "posts_select_auth" on public.posts;
create policy "posts_select_auth" on public.posts
  for select to authenticated using (true);

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts
  for delete to authenticated using (auth.uid() = user_id);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.comments enable row level security;

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select to authenticated using (true);

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own" on public.comments
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "comments_delete_own" on public.comments;
create policy "comments_delete_own" on public.comments
  for delete to authenticated using (auth.uid() = user_id);

create table if not exists public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.likes enable row level security;

drop policy if exists "likes_select_auth" on public.likes;
create policy "likes_select_auth" on public.likes
  for select to authenticated using (true);

drop policy if exists "likes_insert_own" on public.likes;
create policy "likes_insert_own" on public.likes
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "likes_delete_own" on public.likes;
create policy "likes_delete_own" on public.likes
  for delete to authenticated using (auth.uid() = user_id);

-- Visao publica segura (sem cpf_hash/nascimento)
create or replace view public.profiles_public as
  select id,
         display_name,
         relationship_style,
         verification_status,
         created_at
  from public.profiles;

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;
