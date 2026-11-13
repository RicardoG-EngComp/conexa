-- Metadados de midia no R2 e visibilidade de fotos de perfil.
-- Buckets de perfil/estudo sao privados; leitura via Edge Functions.

create table if not exists public.media_objects (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('profile', 'study')),
  variant text not null check (variant in ('full', 'thumb')),
  kind text not null check (
    kind in ('avatar', 'photo', 'study_pdf', 'study_image')
  ),
  object_key text not null,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  sha256 text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (scope, object_key)
);

alter table public.media_objects enable row level security;

-- Sem policies: somente service role (Edge Functions) acessa esta tabela.
create index if not exists media_objects_owner_active_idx
  on public.media_objects (owner_id, scope, kind, created_at desc)
  where deleted_at is null;

create index if not exists media_objects_asset_idx
  on public.media_objects (asset_id);

-- @@

-- Retorna apenas os caminhos de perfil que o usuario autenticado pode ver.
-- O caminho completo e o que fica em profiles.avatar_url/photos; a miniatura
-- e derivada pela Edge Function antes de assinar a URL.
create or replace function public.filter_visible_profile_media(paths text[])
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(array_agg(distinct p), '{}'::text[])
  from unnest(paths) as p
  where auth.uid() is not null
    and public.is_active_user(auth.uid())
    and p is not null
    and length(p) between 3 and 512
    and p not like '/%'
    and p not like '%..%'
    and (
      p like auth.uid()::text || '/%'
      or public.is_admin_user(auth.uid())
      or exists (
        select 1
        from public.profiles pr
        where pr.id::text = split_part(p, '/', 1)
          and pr.account_status = 'active'
          and pr.profile_under_review = false
          and not public.is_blocked(auth.uid(), pr.id)
          and (pr.avatar_url = p or p = any(pr.photos))
          and (
            pr.profile_private = false
            or exists (
              select 1
              from public.connections c
              where c.status = 'accepted'
                and (
                  (c.requester_id = auth.uid() and c.addressee_id = pr.id)
                  or (c.addressee_id = auth.uid() and c.requester_id = pr.id)
                )
            )
          )
      )
    );
$$;

grant execute on function public.filter_visible_profile_media(text[])
  to authenticated;
