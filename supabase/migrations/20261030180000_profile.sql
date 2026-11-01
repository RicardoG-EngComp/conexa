-- B2: perfil completo
alter table public.profiles
  add column if not exists course text,
  add column if not exists campus text,
  add column if not exists bio text,
  add column if not exists prompts jsonb,
  add column if not exists avatar_url text,
  add column if not exists photos text[] not null default '{}',
  add column if not exists interests text[] not null default '{}';

create table if not exists public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('music', 'series', 'movie', 'anime')),
  name text not null,
  external_id text,
  source text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.catalog_items enable row level security;

drop policy if exists "catalog_select_auth" on public.catalog_items;
create policy "catalog_select_auth" on public.catalog_items
  for select to authenticated using (true);

create unique index if not exists catalog_items_category_name_idx
  on public.catalog_items (category, lower(name));

create table if not exists public.profile_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.catalog_items(id) on delete cascade,
  primary key (user_id, item_id)
);

alter table public.profile_favorites enable row level security;

drop policy if exists "favorites_select_auth" on public.profile_favorites;
create policy "favorites_select_auth" on public.profile_favorites
  for select to authenticated using (true);

drop policy if exists "favorites_insert_own" on public.profile_favorites;
create policy "favorites_insert_own" on public.profile_favorites
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "favorites_delete_own" on public.profile_favorites;
create policy "favorites_delete_own" on public.profile_favorites
  for delete to authenticated using (user_id = auth.uid());

create or replace view public.profiles_public as
  select id, display_name, course, campus, bio, prompts, avatar_url, photos,
         interests, relationship_style, verification_status, created_at
  from public.profiles;

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;
