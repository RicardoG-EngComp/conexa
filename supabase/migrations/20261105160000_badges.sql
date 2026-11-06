-- Insignias (badges) e concessao do selo de beta tester

create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  icon text not null default 'military_tech',
  color text not null default '#0F5C5C',
  category text not null default 'geral',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.badges enable row level security;

drop policy if exists "badges_select_auth" on public.badges;
create policy "badges_select_auth" on public.badges
  for select to authenticated using (is_active = true);

drop policy if exists "badges_admin_write" on public.badges;
create policy "badges_admin_write" on public.badges
  for all to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- @@

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

alter table public.user_badges enable row level security;

drop policy if exists "user_badges_select_auth" on public.user_badges;
create policy "user_badges_select_auth" on public.user_badges
  for select to authenticated using (true);

drop policy if exists "user_badges_admin_write" on public.user_badges;
create policy "user_badges_admin_write" on public.user_badges
  for all to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- @@

create or replace function public.admin_grant_badges(
  p_emails text[],
  p_slug text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_badge uuid;
  v_count integer := 0;
  v_user uuid;
  v_email text;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  select id into v_badge
  from public.badges
  where slug = p_slug and is_active = true;

  if v_badge is null then
    raise exception 'badge not found';
  end if;

  foreach v_email in array p_emails loop
    if v_email is null or btrim(v_email) = '' then
      continue;
    end if;

    select id into v_user
    from auth.users
    where lower(email) = lower(btrim(v_email))
    limit 1;

    if v_user is not null then
      insert into public.user_badges (user_id, badge_id, granted_by)
      values (v_user, v_badge, auth.uid())
      on conflict (user_id, badge_id) do nothing;

      if found then
        v_count := v_count + 1;
      end if;
    end if;
  end loop;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    'grant_badges',
    null,
    jsonb_build_object('badge', p_slug, 'granted', v_count)
  );

  return v_count;
end;
$$;

grant execute on function public.admin_grant_badges(text[], text) to authenticated;

-- @@

create or replace function public.admin_grant_badge(
  p_email text,
  p_slug text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.admin_grant_badges(array[p_email], p_slug);
end;
$$;

grant execute on function public.admin_grant_badge(text, text) to authenticated;

-- @@

insert into public.badges (slug, name, description, icon, color, category)
values (
  'testador-oficial-beta-2026',
  'Testador Oficial - Beta 2026',
  'Participou do beta fechado do Conexa em 2026.',
  'science',
  '#0F5C5C',
  'beta'
)
on conflict (slug) do nothing;
