-- P1: midia no feed (imagem e video curto) com R2 privado.

alter table public.media_objects
  drop constraint if exists media_objects_scope_check;
alter table public.media_objects
  add constraint media_objects_scope_check
  check (scope in ('profile', 'study', 'feed'));

alter table public.media_objects
  drop constraint if exists media_objects_kind_check;
alter table public.media_objects
  add constraint media_objects_kind_check
  check (
    kind in (
      'avatar',
      'photo',
      'study_pdf',
      'study_image',
      'feed_image',
      'feed_video'
    )
  );

alter table public.media_objects
  add column if not exists duration_ms integer
    check (duration_ms is null or duration_ms between 1 and 60000);

-- @@

create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  object_key text not null unique,
  kind text not null check (kind in ('image', 'video')),
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_ms integer check (duration_ms is null or duration_ms between 1 and 60000),
  alt_text text check (alt_text is null or char_length(alt_text) <= 300),
  position int not null default 0 check (position between 0 and 3),
  created_at timestamptz not null default now()
);

create index if not exists post_media_post_idx
  on public.post_media (post_id, position);

alter table public.post_media enable row level security;

drop policy if exists "post_media_select_visible" on public.post_media;
create policy "post_media_select_visible" on public.post_media
  for select to authenticated
  using (public.can_view_post(post_id));

drop policy if exists "post_media_insert_own" on public.post_media;
create policy "post_media_insert_own" on public.post_media
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.is_active_user(auth.uid())
    and public.can_view_post(post_id)
  );

drop policy if exists "post_media_delete_own" on public.post_media;
create policy "post_media_delete_own" on public.post_media
  for delete to authenticated using (owner_id = auth.uid());

create or replace function public.validate_post_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if new.owner_id <> auth.uid() then raise exception 'nao_e_dono'; end if;
  if not exists (
    select 1 from public.posts po
    where po.id = new.post_id and po.user_id = auth.uid()
  ) then
    raise exception 'publicacao_inacessivel';
  end if;
  if not exists (
    select 1 from public.media_objects mo
    where mo.owner_id = new.owner_id
      and mo.scope = 'feed'
      and mo.object_key = new.object_key
      and mo.deleted_at is null
      and (
        (new.kind = 'image' and mo.kind = 'feed_image')
        or (new.kind = 'video' and mo.kind = 'feed_video')
      )
  ) then
    raise exception 'midia_invalida';
  end if;

  select count(*) into v_count
  from public.post_media where post_id = new.post_id;

  if new.kind = 'video' and v_count > 0 then
    raise exception 'video_sozinho';
  end if;
  if new.kind = 'image'
     and exists (select 1 from public.post_media where post_id = new.post_id and kind = 'video') then
    raise exception 'video_sozinho';
  end if;
  if v_count >= 4 then
    raise exception 'maximo_midias';
  end if;

  return new;
end;
$$;

drop trigger if exists post_media_validate on public.post_media;
create trigger post_media_validate
before insert on public.post_media
for each row execute function public.validate_post_media();

create or replace function public.filter_visible_feed_media(paths text[])
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(array_agg(distinct pm.object_key), '{}'::text[])
  from public.post_media pm
  where pm.object_key = any(paths)
    and public.is_active_user(auth.uid())
    and public.can_view_post(pm.post_id);
$$;
grant execute on function public.filter_visible_feed_media(text[])
  to authenticated;
