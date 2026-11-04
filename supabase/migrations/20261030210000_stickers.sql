-- Figurinhas e GIFs
create table if not exists public.sticker_packs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id) on delete cascade,
  is_public boolean not null default false,
  source text not null default 'user',
  created_at timestamptz not null default now()
);

alter table public.sticker_packs enable row level security;

-- @@

drop policy if exists "sticker_packs_select" on public.sticker_packs;
create policy "sticker_packs_select" on public.sticker_packs
  for select to authenticated
  using (is_public or owner_id = auth.uid());

drop policy if exists "sticker_packs_insert_own" on public.sticker_packs;
create policy "sticker_packs_insert_own" on public.sticker_packs
  for insert to authenticated with check (owner_id = auth.uid());

drop policy if exists "sticker_packs_delete_own" on public.sticker_packs;
create policy "sticker_packs_delete_own" on public.sticker_packs
  for delete to authenticated using (owner_id = auth.uid());

-- @@

create table if not exists public.stickers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.sticker_packs(id) on delete cascade,
  image_path text not null,
  emoji text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.stickers enable row level security;

-- @@

drop policy if exists "stickers_select" on public.stickers;
create policy "stickers_select" on public.stickers
  for select to authenticated
  using (
    exists (
      select 1 from public.sticker_packs p
      where p.id = pack_id and (p.is_public or p.owner_id = auth.uid())
    )
  );

drop policy if exists "stickers_insert_own" on public.stickers;
create policy "stickers_insert_own" on public.stickers
  for insert to authenticated
  with check (
    exists (
      select 1 from public.sticker_packs p
      where p.id = pack_id and p.owner_id = auth.uid()
    )
  );

drop policy if exists "stickers_delete_own" on public.stickers;
create policy "stickers_delete_own" on public.stickers
  for delete to authenticated
  using (
    exists (
      select 1 from public.sticker_packs p
      where p.id = pack_id and p.owner_id = auth.uid()
    )
  );

-- @@

alter table public.messages
  add column if not exists kind text not null default 'text',
  add column if not exists sticker_path text,
  add column if not exists gif_url text;

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'sticker', 'gif'));

alter table public.messages drop constraint if exists messages_content_check;
alter table public.messages add constraint messages_content_check check (
  (kind = 'text' and char_length(content) between 1 and 2000)
  or (kind = 'sticker' and sticker_path is not null)
  or (kind = 'gif' and gif_url is not null)
);

-- @@

-- Cota de 50 MB por usuario no bucket de figurinhas
create or replace function public.enforce_sticker_quota()
returns trigger
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  total bigint;
begin
  if new.bucket_id <> 'stickers' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;

  select coalesce(sum((metadata->>'size')::bigint), 0) into total
  from storage.objects
  where bucket_id = 'stickers'
    and (storage.foldername(name))[1] = auth.uid()::text;

  if total > 52428800 then
    raise exception 'sticker quota exceeded';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_sticker_quota on storage.objects;
create trigger enforce_sticker_quota
before insert on storage.objects
for each row execute function public.enforce_sticker_quota();
