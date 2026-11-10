-- Bloco 1 (fundacao de grupos): tabelas, normalizacao e nome publico unico.
-- As politicas de RLS e as RPCs entram em groups_security.

create or replace function public.normalize_group_name(p_name text)
returns text
language sql
immutable
set search_path = public
as $$
  select lower(btrim(regexp_replace(
    translate(
      coalesce(p_name, ''),
      'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
      'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'
    ),
    '\s+', ' ', 'g'
  )));
$$;

create or replace function public.is_valid_group_permission(p text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p = any(array[
    'manage_group',
    'manage_roles',
    'manage_members',
    'manage_invites',
    'post_as_group',
    'moderate_content'
  ]);
$$;

-- @@

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 80),
  name_normalized text not null,
  description text check (description is null or char_length(description) <= 1000),
  category text not null default 'outros',
  campus text not null default 'Viçosa',
  course text,
  visibility text not null default 'private'
    check (visibility in ('private', 'public')),
  public_approval text not null default 'none'
    check (public_approval in ('none', 'pending', 'approved', 'rejected')),
  is_official boolean not null default false,
  under_review boolean not null default false,
  archived_at timestamptz,
  avatar_url text,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (visibility = 'public' or public_approval = 'none'),
  check (not is_official or public_approval = 'approved')
);

create unique index if not exists groups_public_name_unique
  on public.groups (name_normalized)
  where visibility = 'public' and archived_at is null;

create index if not exists groups_public_directory_idx
  on public.groups (visibility, public_approval, is_official)
  where archived_at is null;

alter table public.groups enable row level security;

-- @@

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'left', 'removed')),
  invited_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.group_members enable row level security;

-- @@

create table if not exists public.group_roles (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 40),
  permissions text[] not null default '{}',
  is_system boolean not null default false,
  rank int not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists group_roles_name_unique
  on public.group_roles (group_id, lower(btrim(name)));

alter table public.group_roles enable row level security;

-- @@

create table if not exists public.group_member_roles (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.group_roles(id) on delete cascade,
  show_on_profile boolean not null default false,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (group_id, user_id, role_id),
  foreign key (group_id, user_id)
    references public.group_members(group_id, user_id) on delete cascade
);

alter table public.group_member_roles enable row level security;

-- @@

create table if not exists public.group_followers (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.group_followers enable row level security;

-- @@

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  max_uses int not null default 1 check (max_uses > 0),
  used_count int not null default 0 check (used_count >= 0),
  revoked_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists group_invites_group_idx
  on public.group_invites (group_id);

alter table public.group_invites enable row level security;

-- @@

create table if not exists public.group_audit_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_table text,
  target_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists group_audit_group_idx
  on public.group_audit_events (group_id, created_at desc);

alter table public.group_audit_events enable row level security;

-- @@

create or replace function public.set_group_name_normalized()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.name_normalized := public.normalize_group_name(new.name);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists groups_name_normalize on public.groups;
create trigger groups_name_normalize
before insert or update of name on public.groups
for each row execute function public.set_group_name_normalized();
