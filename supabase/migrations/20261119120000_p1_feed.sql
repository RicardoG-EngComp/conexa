-- P1: feed social (bookmark, repost, enquete, edicao, fixar, rascunhos,
-- agendamento, mencoes e notificacoes de interacao).

-- @@

-- 1) Posts: edicao, fixacao, repost simples.

alter table public.posts
  add column if not exists edited_at timestamptz,
  add column if not exists pinned_at timestamptz,
  add column if not exists repost_of_id uuid references public.posts(id) on delete set null,
  add column if not exists was_repost boolean not null default false;

alter table public.posts
  drop constraint if exists posts_no_self_repost;
alter table public.posts
  add constraint posts_no_self_repost
  check (repost_of_id is null or repost_of_id <> id);

alter table public.posts
  drop constraint if exists posts_no_quote_and_repost;
alter table public.posts
  add constraint posts_no_quote_and_repost
  check (quoted_post_id is null or repost_of_id is null);

alter table public.posts
  drop constraint if exists posts_content_check;
alter table public.posts
  add constraint posts_content_check
  check (
    (repost_of_id is not null and char_length(content) = 0)
    or (repost_of_id is null and char_length(content) between 1 and 2000)
  );

create index if not exists posts_repost_idx on public.posts (repost_of_id);
create index if not exists posts_pinned_idx
  on public.posts (user_id, pinned_at desc)
  where pinned_at is not null;

create or replace function public.enforce_post_repost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_original public.posts%rowtype;
begin
  if new.repost_of_id is null then
    new.was_repost := false;
    return new;
  end if;

  if new.quoted_post_id is not null then
    raise exception 'citacao_e_repost_juntos';
  end if;

  select * into v_original from public.posts where id = new.repost_of_id;
  if v_original.id is null or not public.can_view_post(new.repost_of_id) then
    raise exception 'publicacao_inacessivel';
  end if;
  if v_original.user_id = new.user_id then
    raise exception 'nao_pode_republicar_a_si';
  end if;
  if v_original.was_repost then
    raise exception 'nao_pode_republicar_republicacao';
  end if;

  new.content := '';
  new.was_repost := true;
  return new;
end;
$$;

drop trigger if exists posts_enforce_repost on public.posts;
create trigger posts_enforce_repost
before insert on public.posts
for each row execute function public.enforce_post_repost();

-- @@

-- 2) Bookmarks.

create table if not exists public.post_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.post_bookmarks enable row level security;

drop policy if exists "post_bookmarks_select_own" on public.post_bookmarks;
create policy "post_bookmarks_select_own" on public.post_bookmarks
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "post_bookmarks_insert_own" on public.post_bookmarks;
create policy "post_bookmarks_insert_own" on public.post_bookmarks
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_active_user(auth.uid())
    and public.can_view_post(post_id)
  );

drop policy if exists "post_bookmarks_delete_own" on public.post_bookmarks;
create policy "post_bookmarks_delete_own" on public.post_bookmarks
  for delete to authenticated using (user_id = auth.uid());

create or replace function public.toggle_bookmark(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.can_view_post(p_post_id) then raise exception 'publicacao_inacessivel'; end if;

  select exists (
    select 1 from public.post_bookmarks
    where user_id = auth.uid() and post_id = p_post_id
  ) into v_exists;

  if v_exists then
    delete from public.post_bookmarks
    where user_id = auth.uid() and post_id = p_post_id;
  else
    insert into public.post_bookmarks (user_id, post_id)
    values (auth.uid(), p_post_id)
    on conflict do nothing;
  end if;

  return jsonb_build_object('bookmarked', not v_exists);
end;
$$;
grant execute on function public.toggle_bookmark(uuid) to authenticated;

-- @@

-- 3) Edicao e fixacao.

create or replace function public.edit_post(
  p_post_id uuid,
  p_content text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts%rowtype;
  v_content text := btrim(coalesce(p_content, ''));
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception 'conteudo_invalido';
  end if;

  select * into v_post from public.posts where id = p_post_id;
  if v_post.id is null or v_post.user_id <> auth.uid() then
    raise exception 'publicacao_inacessivel';
  end if;
  if v_post.repost_of_id is not null then
    raise exception 'republicacao_nao_editavel';
  end if;
  if v_post.created_at < now() - interval '15 minutes' then
    raise exception 'prazo_de_edicao_expirado';
  end if;

  update public.posts
  set content = v_content,
      edited_at = now()
  where id = p_post_id;

  return jsonb_build_object('edited_at', now());
end;
$$;
grant execute on function public.edit_post(uuid, text) to authenticated;

create or replace function public.pin_post(p_post_id uuid, p_pin boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts%rowtype;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into v_post from public.posts where id = p_post_id;
  if v_post.id is null or v_post.user_id <> auth.uid() then
    raise exception 'publicacao_inacessivel';
  end if;

  update public.posts
  set pinned_at = null
  where user_id = auth.uid() and pinned_at is not null;

  if p_pin then
    update public.posts set pinned_at = now() where id = p_post_id;
  end if;

  return jsonb_build_object('pinned', p_pin);
end;
$$;
grant execute on function public.pin_post(uuid, boolean) to authenticated;

-- @@

-- 4) Enquetes.

create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique references public.posts(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 80),
  position int not null check (position between 0 and 3),
  unique (poll_id, position)
);

create table if not exists public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_id uuid not null references public.poll_options(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);

alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;

drop policy if exists "polls_select_visible" on public.polls;
create policy "polls_select_visible" on public.polls
  for select to authenticated
  using (public.can_view_post(post_id));

drop policy if exists "poll_options_select_visible" on public.poll_options;
create policy "poll_options_select_visible" on public.poll_options
  for select to authenticated
  using (
    exists (
      select 1 from public.polls p
      where p.id = poll_id and public.can_view_post(p.post_id)
    )
  );

drop policy if exists "poll_votes_select_own" on public.poll_votes;
create policy "poll_votes_select_own" on public.poll_votes
  for select to authenticated using (user_id = auth.uid());

create or replace function public.create_poll(
  p_post_id uuid,
  p_options text[],
  p_hours int default 24
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts%rowtype;
  v_poll_id uuid;
  v_option text;
  v_pos int := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select * into v_post from public.posts where id = p_post_id;
  if v_post.id is null or v_post.user_id <> auth.uid() then
    raise exception 'publicacao_inacessivel';
  end if;
  if v_post.repost_of_id is not null then raise exception 'republicacao_sem_enquete'; end if;
  if p_hours < 1 or p_hours > 168 then raise exception 'duracao_invalida'; end if;
  if p_options is null or array_length(p_options, 1) < 2 or array_length(p_options, 1) > 4 then
    raise exception 'opcoes_invalidas';
  end if;
  if exists (select 1 from public.polls where post_id = p_post_id) then
    raise exception 'enquete_ja_existe';
  end if;

  insert into public.polls (post_id, expires_at)
  values (p_post_id, now() + make_interval(hours => p_hours))
  returning id into v_poll_id;

  foreach v_option in array p_options loop
    v_option := btrim(coalesce(v_option, ''));
    if char_length(v_option) < 1 or char_length(v_option) > 80 then
      raise exception 'opcao_invalida';
    end if;
    insert into public.poll_options (poll_id, label, position)
    values (v_poll_id, v_option, v_pos);
    v_pos := v_pos + 1;
  end loop;

  return jsonb_build_object('poll_id', v_poll_id);
end;
$$;
grant execute on function public.create_poll(uuid, text[], int) to authenticated;

create or replace function public.vote_poll(
  p_poll_id uuid,
  p_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll public.polls%rowtype;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select * into v_poll from public.polls where id = p_poll_id;
  if v_poll.id is null or not public.can_view_post(v_poll.post_id) then
    raise exception 'enquete_inacessivel';
  end if;
  if v_poll.expires_at <= now() then raise exception 'enquete_encerrada'; end if;
  if not exists (
    select 1 from public.poll_options
    where id = p_option_id and poll_id = p_poll_id
  ) then
    raise exception 'opcao_invalida';
  end if;

  insert into public.poll_votes (poll_id, option_id, user_id)
  values (p_poll_id, p_option_id, auth.uid())
  on conflict (poll_id, user_id) do update
    set option_id = excluded.option_id,
        created_at = now();

  return jsonb_build_object('voted', true);
end;
$$;
grant execute on function public.vote_poll(uuid, uuid) to authenticated;

create or replace function public.poll_results(p_poll_ids uuid[])
returns table (
  poll_id uuid,
  option_id uuid,
  votes bigint,
  my_vote boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    po.poll_id,
    po.id,
    count(pv.user_id),
    coalesce(bool_or(pv.user_id = auth.uid()), false)
  from public.poll_options po
  join public.polls p on p.id = po.poll_id
  left join public.poll_votes pv
    on pv.poll_id = po.poll_id and pv.option_id = po.id
  where po.poll_id = any(p_poll_ids)
    and public.can_view_post(p.post_id)
  group by po.poll_id, po.id
  order by po.poll_id, po.position;
$$;
grant execute on function public.poll_results(uuid[]) to authenticated;

-- @@

-- 5) Rascunhos e agendamento.

create table if not exists public.post_drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (pg_column_size(payload) <= 20000)
);

alter table public.post_drafts enable row level security;

drop policy if exists "post_drafts_select_own" on public.post_drafts;
create policy "post_drafts_select_own" on public.post_drafts
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "post_drafts_insert_own" on public.post_drafts;
create policy "post_drafts_insert_own" on public.post_drafts
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "post_drafts_update_own" on public.post_drafts;
create policy "post_drafts_update_own" on public.post_drafts
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "post_drafts_delete_own" on public.post_drafts;
create policy "post_drafts_delete_own" on public.post_drafts
  for delete to authenticated using (user_id = auth.uid());

create table if not exists public.scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null,
  scheduled_at timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending', 'published', 'cancelled', 'failed')),
  post_id uuid references public.posts(id) on delete set null,
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (pg_column_size(payload) <= 20000)
);

alter table public.scheduled_posts enable row level security;

drop policy if exists "scheduled_posts_select_own" on public.scheduled_posts;
create policy "scheduled_posts_select_own" on public.scheduled_posts
  for select to authenticated using (user_id = auth.uid());

create index if not exists scheduled_posts_due_idx
  on public.scheduled_posts (scheduled_at)
  where status = 'pending';

create or replace function public.schedule_post(
  p_payload jsonb,
  p_scheduled_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content text := btrim(coalesce(p_payload->>'content', ''));
  v_pending int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then
    raise exception 'diretrizes_necessarias';
  end if;
  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception 'conteudo_invalido';
  end if;
  if p_scheduled_at < now() + interval '5 minutes'
     or p_scheduled_at > now() + interval '30 days' then
    raise exception 'data_invalida';
  end if;

  select count(*) into v_pending
  from public.scheduled_posts
  where user_id = auth.uid() and status = 'pending';
  if v_pending >= 10 then raise exception 'limite_agendamentos'; end if;

  insert into public.scheduled_posts (user_id, payload, scheduled_at)
  values (auth.uid(), p_payload, p_scheduled_at);

  return jsonb_build_object('scheduled_at', p_scheduled_at);
end;
$$;
grant execute on function public.schedule_post(jsonb, timestamptz) to authenticated;

create or replace function public.cancel_scheduled_post(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.scheduled_posts
  set status = 'cancelled', updated_at = now()
  where id = p_id and user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'agendamento_indisponivel'; end if;
  return jsonb_build_object('cancelled', true);
end;
$$;
grant execute on function public.cancel_scheduled_post(uuid) to authenticated;

create or replace function public.publish_due_scheduled_posts()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.scheduled_posts%rowtype;
  v_content text;
  v_visibility text;
  v_reply_policy text;
  v_post_id uuid;
  v_topic uuid;
  v_mention uuid;
  v_option text;
  v_pos int;
  v_poll_id uuid;
  v_count int;
  v_published int := 0;
  v_failed int := 0;
begin
  for v_row in
    select * from public.scheduled_posts
    where status = 'pending' and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    begin
      if not public.is_active_user(v_row.user_id)
         or not public.has_accepted_guidelines(v_row.user_id) then
        raise exception 'conta_indisponivel';
      end if;

      perform set_config('request.jwt.claim.sub', v_row.user_id::text, true);
      perform set_config(
        'request.jwt.claims',
        jsonb_build_object('sub', v_row.user_id::text)::text,
        true
      );

      v_content := btrim(coalesce(v_row.payload->>'content', ''));
      v_visibility := coalesce(v_row.payload->>'visibility', 'public');
      v_reply_policy := coalesce(v_row.payload->>'reply_policy', 'anyone');

      if char_length(v_content) < 1 or char_length(v_content) > 2000 then
        raise exception 'conteudo_invalido';
      end if;
      if v_visibility not in ('public', 'friends') then
        raise exception 'visibilidade_invalida';
      end if;
      if v_reply_policy not in ('anyone', 'connections') then
        raise exception 'resposta_invalida';
      end if;
      if public.content_policy_category(v_content) is not null then
        raise exception 'conteudo_proibido';
      end if;

      v_post_id := gen_random_uuid();
      insert into public.posts (
        id, user_id, content, visibility, reply_policy, posted_as_group
      ) values (
        v_post_id, v_row.user_id, v_content, v_visibility, v_reply_policy, false
      );

      for v_topic in
        select value::uuid
        from jsonb_array_elements_text(
          coalesce(v_row.payload->'topic_ids', '[]'::jsonb)
        )
        limit 5
      loop
        insert into public.post_topics (post_id, topic_id)
        values (v_post_id, v_topic)
        on conflict do nothing;
      end loop;

      for v_mention in
        select value::uuid
        from jsonb_array_elements_text(
          coalesce(v_row.payload->'mentions', '[]'::jsonb)
        )
        limit 10
      loop
        if v_mention <> v_row.user_id
           and public.is_active_user(v_mention)
           and not public.is_blocked(v_row.user_id, v_mention) then
          insert into public.post_mentions (post_id, user_id, mentioned_by)
          values (v_post_id, v_mention, v_row.user_id)
          on conflict do nothing;
        end if;
      end loop;

      if v_row.payload->'poll' is not null then
        select count(*) into v_count
        from jsonb_array_elements(v_row.payload->'poll'->'options');
        if v_count between 2 and 4 then
          insert into public.polls (post_id, expires_at)
          values (
            v_post_id,
            now() + make_interval(
              hours => greatest(
                1,
                least(168, coalesce((v_row.payload->'poll'->>'hours')::int, 24))
              )
            )
          )
          returning id into v_poll_id;

          v_pos := 0;
          for v_option in
            select value
            from jsonb_array_elements_text(v_row.payload->'poll'->'options')
          loop
            if char_length(btrim(v_option)) between 1 and 80 then
              insert into public.poll_options (poll_id, label, position)
              values (v_poll_id, btrim(v_option), v_pos);
            end if;
            v_pos := v_pos + 1;
          end loop;
        end if;
      end if;

      update public.scheduled_posts
      set status = 'published', post_id = v_post_id, updated_at = now()
      where id = v_row.id;
      v_published := v_published + 1;
    exception when others then
      update public.scheduled_posts
      set status = 'failed', error = sqlerrm, updated_at = now()
      where id = v_row.id;
      v_failed := v_failed + 1;
    end;
  end loop;

  return jsonb_build_object('published', v_published, 'failed', v_failed);
end;
$$;

revoke all on function public.publish_due_scheduled_posts()
  from public, anon, authenticated;
grant execute on function public.publish_due_scheduled_posts() to service_role;

-- @@

-- 6) Mencoes.

create table if not exists public.post_mentions (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  mentioned_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_mentions enable row level security;

drop policy if exists "post_mentions_select_visible" on public.post_mentions;
create policy "post_mentions_select_visible" on public.post_mentions
  for select to authenticated using (public.can_view_post(post_id));

create or replace function public.set_post_mentions(
  p_post_id uuid,
  p_user_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts%rowtype;
  v_target uuid;
  v_count int := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select * into v_post from public.posts where id = p_post_id;
  if v_post.id is null or v_post.user_id <> auth.uid() then
    raise exception 'publicacao_inacessivel';
  end if;

  delete from public.post_mentions where post_id = p_post_id;

  if p_user_ids is not null then
    for v_target in
      select distinct value from unnest(p_user_ids) as t(value) limit 10
    loop
      if v_target = auth.uid() then continue; end if;
      if not public.is_active_user(v_target) then continue; end if;
      if public.is_blocked(auth.uid(), v_target) then continue; end if;
      insert into public.post_mentions (post_id, user_id, mentioned_by)
      values (p_post_id, v_target, auth.uid())
      on conflict do nothing;
      v_count := v_count + 1;
    end loop;
  end if;

  return jsonb_build_object('mentions', v_count);
end;
$$;
grant execute on function public.set_post_mentions(uuid, uuid[]) to authenticated;

-- @@

-- 7) Notificacoes de interacao.

alter table public.notification_preferences
  add column if not exists interactions boolean not null default true;

alter table public.notifications
  drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'message_request',
    'message',
    'connection_request',
    'connection_accepted',
    'study_pending',
    'study_approved',
    'study_rejected',
    'group_invite',
    'security_alert',
    'like',
    'comment',
    'mention',
    'repost'
  ));

create or replace function public.notification_type_enabled(
  p_user_id uuid,
  p_type text
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select case
        when p_type = 'message_request' then p.message_requests
        when p_type = 'message' then p.messages
        when p_type in ('connection_request', 'connection_accepted') then p.connections
        when p_type in ('study_pending', 'study_approved', 'study_rejected') then p.studies
        when p_type = 'group_invite' then p.groups
        when p_type = 'security_alert' then p.security_alerts
        when p_type in ('like', 'comment', 'mention', 'repost') then p.interactions
        else false
      end
      from public.notification_preferences p
      where p.user_id = p_user_id
    ),
    true
  );
$$;

revoke all on function public.notification_type_enabled(uuid, text)
  from public, anon, authenticated;

create or replace function public.notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_hidden timestamptz;
begin
  select user_id, hidden_at into v_author, v_hidden
  from public.posts where id = new.post_id;

  if v_author is null or v_author = new.user_id or v_hidden is not null then
    return new;
  end if;
  if not public.is_active_user(v_author)
     or public.is_blocked(v_author, new.user_id) then
    return new;
  end if;

  perform public.enqueue_notification(
    v_author,
    'like',
    'Nova curtida',
    'Sua publicacao recebeu uma curtida.',
    jsonb_build_object('route', '/feed/' || new.post_id, 'post_id', new.post_id)
  );
  return new;
end;
$$;

drop trigger if exists likes_notify_post_author on public.likes;
create trigger likes_notify_post_author
after insert on public.likes
for each row execute function public.notify_post_like();

create or replace function public.notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_parent_author uuid;
  v_target uuid;
begin
  select user_id into v_author from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select user_id into v_parent_author from public.comments where id = new.parent_id;
  end if;

  for v_target in
    select distinct value from unnest(array[v_author, v_parent_author]) as t(value)
    where value is not null
  loop
    if v_target = new.user_id then continue; end if;
    if not public.is_active_user(v_target)
       or public.is_blocked(v_target, new.user_id) then
      continue;
    end if;
    perform public.enqueue_notification(
      v_target,
      'comment',
      'Nova resposta',
      'Sua publicacao recebeu uma resposta.',
      jsonb_build_object('route', '/feed/' || new.post_id, 'post_id', new.post_id)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists comments_notify_authors on public.comments;
create trigger comments_notify_authors
after insert on public.comments
for each row execute function public.notify_post_comment();

create or replace function public.notify_post_mention()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id = new.mentioned_by then return new; end if;
  if not public.is_active_user(new.user_id)
     or public.is_blocked(new.user_id, new.mentioned_by) then
    return new;
  end if;

  perform public.enqueue_notification(
    new.user_id,
    'mention',
    'Voce foi mencionado',
    'Uma publicacao mencionou voce.',
    jsonb_build_object('route', '/feed/' || new.post_id, 'post_id', new.post_id)
  );
  return new;
end;
$$;

drop trigger if exists post_mentions_notify on public.post_mentions;
create trigger post_mentions_notify
after insert on public.post_mentions
for each row execute function public.notify_post_mention();

create or replace function public.notify_post_repost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
begin
  if not new.was_repost or new.repost_of_id is null then return new; end if;

  select user_id into v_author from public.posts where id = new.repost_of_id;
  if v_author is null or v_author = new.user_id then return new; end if;
  if not public.is_active_user(v_author)
     or public.is_blocked(v_author, new.user_id) then
    return new;
  end if;

  perform public.enqueue_notification(
    v_author,
    'repost',
    'Nova republicacao',
    'Sua publicacao foi republicada.',
    jsonb_build_object('route', '/feed/' || new.id, 'post_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists posts_notify_repost on public.posts;
create trigger posts_notify_repost
after insert on public.posts
for each row execute function public.notify_post_repost();

-- @@

-- 8) Feeds respeitam mutes na publicacao original do repost.

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
