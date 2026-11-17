-- P3: descoberta (busca global, feeds personalizados, nao interessado e
-- analytics agregado).

-- @@

-- 1) Nao interessado.

create table if not exists public.post_not_interested (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.post_not_interested enable row level security;

drop policy if exists "not_interested_select_own" on public.post_not_interested;
create policy "not_interested_select_own" on public.post_not_interested
  for select to authenticated using (user_id = auth.uid());

create or replace function public.set_not_interested(
  p_post_id uuid,
  p_hidden boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.can_view_post(p_post_id) then raise exception 'publicacao_inacessivel'; end if;

  if p_hidden then
    insert into public.post_not_interested (user_id, post_id)
    values (auth.uid(), p_post_id)
    on conflict do nothing;
  else
    delete from public.post_not_interested
    where user_id = auth.uid() and post_id = p_post_id;
  end if;

  return jsonb_build_object('hidden', p_hidden);
end;
$$;
grant execute on function public.set_not_interested(uuid, boolean)
  to authenticated;

-- @@

-- 2) Feeds personalizados.

create table if not exists public.custom_feeds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  topic_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.custom_feeds enable row level security;

drop policy if exists "custom_feeds_select_own" on public.custom_feeds;
create policy "custom_feeds_select_own" on public.custom_feeds
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "custom_feeds_insert_own" on public.custom_feeds;
create policy "custom_feeds_insert_own" on public.custom_feeds
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "custom_feeds_update_own" on public.custom_feeds;
create policy "custom_feeds_update_own" on public.custom_feeds
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "custom_feeds_delete_own" on public.custom_feeds;
create policy "custom_feeds_delete_own" on public.custom_feeds
  for delete to authenticated using (user_id = auth.uid());

create or replace function public.validate_custom_feed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic uuid;
  v_count int;
begin
  new.name := btrim(coalesce(new.name, ''));
  if char_length(new.name) < 3 or char_length(new.name) > 40 then
    raise exception 'nome_invalido';
  end if;
  if new.topic_ids is null
     or array_length(new.topic_ids, 1) < 1
     or array_length(new.topic_ids, 1) > 5 then
    raise exception 'topicos_invalidos';
  end if;

  for v_topic in select distinct value from unnest(new.topic_ids) as t(value)
  loop
    if not exists (
      select 1 from public.topics where id = v_topic and is_active
    ) then
      raise exception 'topico_invalido';
    end if;
  end loop;

  if tg_op = 'INSERT' then
    select count(*) into v_count
    from public.custom_feeds where user_id = auth.uid();
    if v_count >= 20 then raise exception 'limite_feeds'; end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists custom_feeds_validate on public.custom_feeds;
create trigger custom_feeds_validate
before insert or update on public.custom_feeds
for each row execute function public.validate_custom_feed();

create or replace function public.feed_custom(
  p_feed_id uuid,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null or not public.is_active_user(v_me) then return; end if;

  return query
  select po.id, po.created_at
  from public.custom_feeds f
  join public.posts po
    on exists (
      select 1 from public.post_topics pt
      where pt.post_id = po.id and pt.topic_id = any(f.topic_ids)
    )
  where f.id = p_feed_id
    and f.user_id = v_me
    and po.hidden_at is null
    and public.can_view_post(po.id)
    and not public.is_blocked(v_me, po.user_id)
    and not public.is_muted_by(v_me, po.user_id)
    and not public.content_has_muted_word(v_me, po.content)
    and not exists (
      select 1 from public.post_not_interested ni
      where ni.user_id = v_me and ni.post_id = po.id
    )
    and not exists (
      select 1 from public.posts orig
      where orig.id = po.repost_of_id
        and (
          public.is_muted_by(v_me, orig.user_id)
          or public.content_has_muted_word(v_me, orig.content)
        )
    )
  order by po.created_at desc, po.id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.feed_custom(uuid, int, int) to authenticated;

-- @@

-- 3) Busca global de posts (full-text em portugues).

alter table public.posts
  add column if not exists search_vector tsvector
    generated always as (to_tsvector('portuguese', coalesce(content, ''))) stored;

create index if not exists posts_search_idx
  on public.posts using gin (search_vector);

create or replace function public.search_posts(
  p_query text,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  rank real
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_query tsquery;
begin
  if v_me is null or not public.is_active_user(v_me) then return; end if;
  if p_query is null or btrim(p_query) = '' then return; end if;

  v_query := websearch_to_tsquery('portuguese', p_query);

  return query
  select po.id, ts_rank(po.search_vector, v_query)
  from public.posts po
  where po.hidden_at is null
    and po.search_vector @@ v_query
    and public.can_view_post(po.id)
    and not public.is_blocked(v_me, po.user_id)
    and not public.is_muted_by(v_me, po.user_id)
    and not public.content_has_muted_word(v_me, po.content)
    and not exists (
      select 1 from public.post_not_interested ni
      where ni.user_id = v_me and ni.post_id = po.id
    )
    and not exists (
      select 1 from public.posts orig
      where orig.id = po.repost_of_id
        and (
          public.is_muted_by(v_me, orig.user_id)
          or public.content_has_muted_word(v_me, orig.content)
        )
    )
  order by 2 desc, po.created_at desc, po.id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.search_posts(text, int, int) to authenticated;

-- @@

-- 4) Analytics agregado do proprio autor.

create or replace function public.my_analytics(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid := auth.uid();
  v_days int := greatest(1, least(365, coalesce(p_days, 30)));
  v_since timestamptz := now() - make_interval(days => v_days);
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(v_me) then raise exception 'conta_inativa'; end if;

  return jsonb_build_object(
    'days', v_days,
    'posts', (
      select count(*) from public.posts
      where user_id = v_me and created_at >= v_since and hidden_at is null
    ),
    'likes', (
      select count(*) from public.likes l
      join public.posts p on p.id = l.post_id
      where p.user_id = v_me and p.created_at >= v_since and p.hidden_at is null
    ),
    'comments', (
      select count(*) from public.comments c
      join public.posts p on p.id = c.post_id
      where p.user_id = v_me and p.created_at >= v_since and p.hidden_at is null
        and c.hidden_at is null
    ),
    'reposts', (
      select count(*) from public.posts r
      join public.posts p on p.id = r.repost_of_id
      where p.user_id = v_me and p.created_at >= v_since and p.hidden_at is null
        and r.hidden_at is null
    ),
    'bookmarks', (
      select count(*) from public.post_bookmarks b
      join public.posts p on p.id = b.post_id
      where p.user_id = v_me and p.created_at >= v_since and p.hidden_at is null
    ),
    'poll_votes', (
      select count(*) from public.poll_votes pv
      join public.polls pl on pl.id = pv.poll_id
      join public.posts p on p.id = pl.post_id
      where p.user_id = v_me and p.created_at >= v_since and p.hidden_at is null
    ),
    'top_posts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'post_id', t.id,
          'preview', left(t.content, 120),
          'likes', t.likes,
          'comments', t.comments,
          'reposts', t.reposts,
          'bookmarks', t.bookmarks,
          'engagement', t.engagement
        )
        order by t.engagement desc, t.created_at desc
      )
      from (
        select
          base.id,
          base.content,
          base.created_at,
          base.likes,
          base.comments,
          base.reposts,
          base.bookmarks,
          base.likes + base.comments + base.reposts + base.bookmarks as engagement
        from (
          select
            p.id,
            p.content,
            p.created_at,
            (
              select count(*) from public.likes l where l.post_id = p.id
            ) as likes,
            (
              select count(*) from public.comments c
              where c.post_id = p.id and c.hidden_at is null
            ) as comments,
            (
              select count(*) from public.posts r
              where r.repost_of_id = p.id and r.hidden_at is null
            ) as reposts,
            (
              select count(*) from public.post_bookmarks b
              where b.post_id = p.id
            ) as bookmarks
          from public.posts p
          where p.user_id = v_me and p.created_at >= v_since
            and p.hidden_at is null
        ) base
        order by engagement desc, created_at desc
        limit 5
      ) t
    ), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.my_analytics(int) to authenticated;

-- @@

-- 5) Feeds existentes respeitam "nao interessado".

create or replace function public.feed_for_you(
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  score int,
  course_match boolean,
  campus_match boolean,
  interest_match boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_course text;
  v_campus text;
  v_interests text[];
begin
  if v_me is null then return; end if;
  if not public.is_active_user(v_me) then return; end if;

  select p.course, p.campus, p.interests
  into v_course, v_campus, v_interests
  from public.profiles p
  where p.id = v_me;

  return query
  with m as (
    select
      po.id,
      po.created_at,
      case when v_course is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'course'
          and lower(tp.label) = lower(v_course)
      ) then 1 else 0 end as cm,
      case when v_campus is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'campus'
          and lower(tp.label) = lower(v_campus)
      ) then 1 else 0 end as cam,
      case when v_interests is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'event_category'
          and lower(tp.label) in (select lower(x) from unnest(v_interests) x)
      ) then 1 else 0 end as im
    from public.posts po
    where po.hidden_at is null
      and po.created_at > now() - interval '30 days'
      and po.user_id <> v_me
      and not public.is_blocked(v_me, po.user_id)
      and not public.is_muted_by(v_me, po.user_id)
      and not public.content_has_muted_word(v_me, po.content)
      and not exists (
        select 1 from public.post_not_interested ni
        where ni.user_id = v_me and ni.post_id = po.id
      )
      and not exists (
        select 1 from public.posts orig
        where orig.id = po.repost_of_id
          and (
            public.is_muted_by(v_me, orig.user_id)
            or public.content_has_muted_word(v_me, orig.content)
          )
      )
      and exists (
        select 1 from public.profiles pr
        where pr.id = po.user_id
          and pr.account_status = 'active'
          and pr.profile_under_review = false
      )
      and (
        (
          po.group_id is null
          and po.visibility = 'public'
          and exists (
            select 1 from public.profiles pr
            where pr.id = po.user_id
              and pr.account_status = 'active'
              and pr.profile_private = false
          )
        )
        or (
          po.group_id is not null
          and exists (
            select 1 from public.groups g
            where g.id = po.group_id
              and g.archived_at is null
              and g.visibility = 'public'
              and g.public_approval = 'approved'
              and g.is_official
              and g.under_review = false
          )
        )
      )
  )
  select
    m.id,
    (3*m.cm + 2*m.cam + 2*m.im
      + case when m.created_at > now() - interval '24 hours' then 1 else 0 end
      + case when m.created_at > now() - interval '7 days' then 1 else 0 end)::int,
    m.cm = 1,
    m.cam = 1,
    m.im = 1
  from m
  order by 2 desc, m.created_at desc, m.id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.feed_for_you(int, int) to authenticated;

create or replace function public.feed_connections(
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  source text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then return; end if;
  if not public.is_active_user(v_me) then return; end if;

  return query
  select x.post_id, x.source
  from (
    select po.id as post_id, 'own'::text as source, po.created_at
    from public.posts po
    where po.user_id = v_me
      and po.group_id is null
      and po.hidden_at is null

    union all

    select po.id, 'connection', po.created_at
    from public.posts po
    join public.connections c
      on c.status = 'accepted'
      and (
        (c.requester_id = v_me and c.addressee_id = po.user_id)
        or (c.requester_id = po.user_id and c.addressee_id = v_me)
      )
    where po.group_id is null
      and po.hidden_at is null
      and not public.is_blocked(v_me, po.user_id)
      and not public.is_muted_by(v_me, po.user_id)
      and not public.content_has_muted_word(v_me, po.content)
      and not exists (
        select 1 from public.post_not_interested ni
        where ni.user_id = v_me and ni.post_id = po.id
      )
      and not exists (
        select 1 from public.posts orig
        where orig.id = po.repost_of_id
          and (
            public.is_muted_by(v_me, orig.user_id)
            or public.content_has_muted_word(v_me, orig.content)
          )
      )
      and exists (
        select 1 from public.profiles pr
        where pr.id = po.user_id
          and pr.account_status = 'active'
          and pr.profile_under_review = false
      )

    union all

    select po.id, 'group_followed', po.created_at
    from public.posts po
    join public.group_followers gf
      on gf.group_id = po.group_id and gf.user_id = v_me
    join public.groups g
      on g.id = po.group_id
      and g.archived_at is null
      and g.visibility = 'public'
      and g.public_approval = 'approved'
      and g.is_official
      and g.under_review = false
    where po.hidden_at is null
      and not public.is_blocked(v_me, po.user_id)
      and not public.is_muted_by(v_me, po.user_id)
      and not public.content_has_muted_word(v_me, po.content)
      and not exists (
        select 1 from public.post_not_interested ni
        where ni.user_id = v_me and ni.post_id = po.id
      )
      and not exists (
        select 1 from public.posts orig
        where orig.id = po.repost_of_id
          and (
            public.is_muted_by(v_me, orig.user_id)
            or public.content_has_muted_word(v_me, orig.content)
          )
      )
      and exists (
        select 1 from public.profiles pr
        where pr.id = po.user_id
          and pr.account_status = 'active'
          and pr.profile_under_review = false
      )
  ) x
  order by x.created_at desc, x.post_id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.feed_connections(int, int) to authenticated;
