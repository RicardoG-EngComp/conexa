-- P0: privacidade e confianca.
-- Mutes (usuarios/palavras), controle de respostas, status/apelacao de
-- denuncia, exportacao de dados, dispositivos/alertas de login e moderacao.

-- @@

-- 1) Mutes de usuarios e palavras.

create table if not exists public.user_mutes (
  muter_id uuid not null references auth.users(id) on delete cascade,
  muted_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  check (muter_id <> muted_id)
);

alter table public.user_mutes enable row level security;

revoke all on table public.user_mutes from anon, authenticated;
grant select on table public.user_mutes to authenticated;

drop policy if exists "user_mutes_select_own" on public.user_mutes;
create policy "user_mutes_select_own" on public.user_mutes
  for select to authenticated using (muter_id = auth.uid());

create table if not exists public.muted_words (
  user_id uuid not null references auth.users(id) on delete cascade,
  word text not null check (char_length(word) between 2 and 40),
  created_at timestamptz not null default now(),
  primary key (user_id, word)
);

alter table public.muted_words enable row level security;

revoke all on table public.muted_words from anon, authenticated;
grant select on table public.muted_words to authenticated;

drop policy if exists "muted_words_select_own" on public.muted_words;
create policy "muted_words_select_own" on public.muted_words
  for select to authenticated using (user_id = auth.uid());

create or replace function public.is_muted(target_user uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.user_mutes m
    where m.muter_id = auth.uid() and m.muted_id = target_user
  );
$$;
grant execute on function public.is_muted(uuid) to authenticated;

create or replace function public.is_muted_by(muter uuid, target_user uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.user_mutes m
    where m.muter_id = muter and m.muted_id = target_user
  );
$$;
revoke all on function public.is_muted_by(uuid, uuid) from public, anon, authenticated;

create or replace function public.content_has_muted_word(
  p_user_id uuid,
  p_content text
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.muted_words mw
    where mw.user_id = p_user_id
      and position(mw.word in lower(coalesce(p_content, ''))) > 0
  );
$$;
revoke all on function public.content_has_muted_word(uuid, text)
  from public, anon, authenticated;

create or replace function public.mute_user(p_target uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if p_target is null or p_target = auth.uid() then raise exception 'alvo_invalido'; end if;
  if not exists (select 1 from public.profiles where id = p_target) then
    raise exception 'alvo_invalido';
  end if;

  insert into public.user_mutes (muter_id, muted_id)
  values (auth.uid(), p_target)
  on conflict do nothing;

  return jsonb_build_object('muted', true);
end;
$$;
grant execute on function public.mute_user(uuid) to authenticated;

create or replace function public.unmute_user(p_target uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.user_mutes
  where muter_id = auth.uid() and muted_id = p_target;
  return jsonb_build_object('muted', false);
end;
$$;
grant execute on function public.unmute_user(uuid) to authenticated;

create or replace function public.list_muted_users()
returns table (
  id uuid,
  display_name text,
  avatar_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.display_name, p.avatar_url
  from public.user_mutes m
  join public.profiles_public p on p.id = m.muted_id
  where m.muter_id = auth.uid()
  order by m.created_at desc;
$$;
grant execute on function public.list_muted_users() to authenticated;

create or replace function public.add_muted_word(p_word text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_word text;
  v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  v_word := lower(btrim(regexp_replace(coalesce(p_word, ''), '\s+', ' ', 'g')));
  if char_length(v_word) < 2 or char_length(v_word) > 40 then
    raise exception 'palavra_invalida';
  end if;

  select count(*) into v_count from public.muted_words where user_id = auth.uid();
  if v_count >= 200 then raise exception 'limite_palavras'; end if;

  insert into public.muted_words (user_id, word)
  values (auth.uid(), v_word)
  on conflict do nothing;

  return jsonb_build_object('word', v_word);
end;
$$;
grant execute on function public.add_muted_word(text) to authenticated;

create or replace function public.remove_muted_word(p_word text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_word text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  v_word := lower(btrim(regexp_replace(coalesce(p_word, ''), '\s+', ' ', 'g')));
  delete from public.muted_words
  where user_id = auth.uid() and word = v_word;
  return jsonb_build_object('removed', true);
end;
$$;
grant execute on function public.remove_muted_word(text) to authenticated;

-- @@

-- 2) Controle de quem pode responder.

alter table public.posts
  add column if not exists reply_policy text not null default 'anyone';

alter table public.posts
  drop constraint if exists posts_reply_policy_check;
alter table public.posts
  add constraint posts_reply_policy_check
  check (reply_policy in ('anyone', 'connections'));

create or replace function public.enforce_reply_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post public.posts%rowtype;
begin
  if not public.can_view_post(new.post_id) then
    raise exception 'publicacao_inacessivel';
  end if;

  select * into v_post from public.posts where id = new.post_id;
  if v_post.id is null then raise exception 'publicacao_inacessivel'; end if;

  if new.user_id = v_post.user_id then
    return new;
  end if;

  if v_post.group_id is not null
     and not public.is_group_member(v_post.group_id, new.user_id) then
    raise exception 'respostas_restritas';
  end if;

  if v_post.reply_policy = 'connections'
     and not public.is_connection(new.user_id, v_post.user_id) then
    raise exception 'respostas_restritas';
  end if;

  return new;
end;
$$;

drop trigger if exists comments_enforce_reply_policy on public.comments;
create trigger comments_enforce_reply_policy
before insert on public.comments
for each row execute function public.enforce_reply_policy();

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select to authenticated
  using (
    public.can_view_post(post_id)
    and hidden_at is null
    and not public.is_blocked(auth.uid(), user_id)
    and not public.is_muted(user_id)
  );

-- @@

-- 3) Feed e descoberta respeitam mutes.

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

create or replace function public.discover_profiles(
  p_limit int default 30,
  p_offset int default 0,
  p_course text default null,
  p_search text default null
)
returns table (
  id uuid,
  display_name text,
  course text,
  campus text,
  avatar_url text,
  verification_status text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.display_name, p.course, p.campus, p.avatar_url,
         p.verification_status
  from public.profiles p
  where p.id <> auth.uid()
    and p.account_status = 'active'
    and p.profile_under_review = false
    and public.is_active_user(auth.uid())
    and p.display_name is not null and length(btrim(p.display_name)) > 0
    and p.course is not null and length(btrim(p.course)) > 0
    and p.campus is not null and length(btrim(p.campus)) > 0
    and p.avatar_url is not null and length(btrim(p.avatar_url)) > 0
    and (p_course is null or p.course = p_course)
    and (
      p_search is null or btrim(p_search) = ''
      or p.display_name ilike '%' || p_search || '%'
      or p.course ilike '%' || p_search || '%'
    )
    and not public.is_blocked(auth.uid(), p.id)
    and not public.is_muted(p.id)
  order by p.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;
grant execute on function public.discover_profiles(int, int, text, text) to authenticated;

-- @@

-- 4) Status e apelacao de denuncia.

alter table public.reports
  add column if not exists appeal_reason text,
  add column if not exists appeal_status text not null default 'none',
  add column if not exists appeal_created_at timestamptz,
  add column if not exists appeal_reviewed_at timestamptz,
  add column if not exists appeal_reviewer_id uuid references auth.users(id),
  add column if not exists appeal_result text;

alter table public.reports
  drop constraint if exists reports_appeal_status_check;
alter table public.reports
  add constraint reports_appeal_status_check
  check (appeal_status in ('none', 'pending', 'accepted', 'rejected'));

create or replace function public.submit_report_appeal(
  p_report_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := btrim(coalesce(p_reason, ''));
  v_report public.reports%rowtype;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if char_length(v_reason) < 10 or char_length(v_reason) > 2000 then
    raise exception 'motivo_invalido';
  end if;

  update public.reports
  set appeal_reason = v_reason,
      appeal_status = 'pending',
      appeal_created_at = now()
  where id = p_report_id
    and reporter_id = auth.uid()
    and status in ('resolved', 'dismissed')
    and appeal_status in ('none', 'rejected')
  returning * into v_report;

  if v_report.id is null then
    raise exception 'apelacao_indisponivel';
  end if;

  return jsonb_build_object('appeal_status', 'pending');
end;
$$;
grant execute on function public.submit_report_appeal(uuid, text) to authenticated;

create or replace function public.admin_resolve_report_appeal(
  p_report_id uuid,
  p_accept boolean,
  p_result text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports%rowtype;
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'forbidden'; end if;

  update public.reports
  set appeal_status = case when p_accept then 'accepted' else 'rejected' end,
      appeal_reviewed_at = now(),
      appeal_reviewer_id = auth.uid(),
      appeal_result = nullif(btrim(coalesce(p_result, '')), '')
  where id = p_report_id and appeal_status = 'pending'
  returning * into v_report;

  if v_report.id is null then raise exception 'apelacao_indisponivel'; end if;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    'report_appeal_resolved',
    v_report.reported_user_id,
    jsonb_build_object(
      'report_id', v_report.id,
      'accepted', p_accept,
      'result', v_report.appeal_result
    )
  );

  return jsonb_build_object('appeal_status', v_report.appeal_status);
end;
$$;
grant execute on function public.admin_resolve_report_appeal(uuid, boolean, text) to authenticated;

-- @@

-- 5) Exportacao de dados do titular (LGPD).

create table if not exists public.user_devices (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(device_id) between 8 and 128),
  label text not null check (char_length(label) between 1 and 80),
  platform text not null default 'unknown'
    check (platform in ('android', 'ios', 'web', 'unknown')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(v_uid) then raise exception 'conta_inativa'; end if;

  return jsonb_build_object(
    'exported_at', now(),
    'account', (
      select jsonb_build_object(
        'email', u.email,
        'created_at', u.created_at,
        'last_sign_in_at', u.last_sign_in_at
      )
      from auth.users u where u.id = v_uid
    ),
    'profile', (
      select to_jsonb(p) - 'cpf_hash'
      from public.profiles p where p.id = v_uid
    ),
    'posts', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.posts x where x.user_id = v_uid
    ), '[]'::jsonb),
    'comments', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.comments x where x.user_id = v_uid
    ), '[]'::jsonb),
    'likes', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.likes x where x.user_id = v_uid
    ), '[]'::jsonb),
    'connections', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.connections x
      where x.requester_id = v_uid or x.addressee_id = v_uid
    ), '[]'::jsonb),
    'blocks', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.blocks x where x.blocker_id = v_uid
    ), '[]'::jsonb),
    'mutes', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.user_mutes x where x.muter_id = v_uid
    ), '[]'::jsonb),
    'muted_words', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.muted_words x where x.user_id = v_uid
    ), '[]'::jsonb),
    'conversations', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.conversations x
      where exists (
        select 1 from public.conversation_participants p
        where p.conversation_id = x.id and p.user_id = v_uid
      )
    ), '[]'::jsonb),
    'messages', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.messages x
      where exists (
        select 1 from public.conversation_participants p
        where p.conversation_id = x.conversation_id and p.user_id = v_uid
      )
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.reports x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'consents', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.consents x where x.user_id = v_uid
    ), '[]'::jsonb),
    'badges', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.user_badges x where x.user_id = v_uid
    ), '[]'::jsonb),
    'study_materials', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.study_materials x where x.author_id = v_uid
    ), '[]'::jsonb),
    'study_votes', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.study_material_votes x where x.user_id = v_uid
    ), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_members x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_roles', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_member_roles x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_follows', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_followers x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_invites', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_invites x
      where x.target_user_id = v_uid or x.created_by = v_uid
    ), '[]'::jsonb),
    'bug_reports', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.bug_reports x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'suggestions', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.suggestions x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'notifications', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.notifications x where x.user_id = v_uid
    ), '[]'::jsonb),
    'notification_preferences', (
      select to_jsonb(x)
      from public.notification_preferences x where x.user_id = v_uid
    ),
    'devices', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.last_seen_at desc)
      from public.user_devices x where x.user_id = v_uid
    ), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.export_my_data() to authenticated;

-- @@

-- 6) Dispositivos e alertas de novo acesso.

create table if not exists public.user_devices (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null check (char_length(device_id) between 8 and 128),
  label text not null check (char_length(label) between 1 and 80),
  platform text not null default 'unknown'
    check (platform in ('android', 'ios', 'web', 'unknown')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

alter table public.user_devices enable row level security;

revoke all on table public.user_devices from anon, authenticated;
grant select on table public.user_devices to authenticated;

drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own" on public.user_devices
  for select to authenticated using (user_id = auth.uid());

alter table public.notification_preferences
  add column if not exists security_alerts boolean not null default true;

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
    'security_alert'
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

create or replace function public.register_device_session(
  p_device_id text,
  p_label text,
  p_platform text default 'unknown'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_first boolean;
  v_new boolean;
  v_platform text := lower(coalesce(p_platform, 'unknown'));
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(v_uid) then raise exception 'conta_inativa'; end if;
  if char_length(coalesce(p_device_id, '')) < 8
     or char_length(p_device_id) > 128 then
    raise exception 'dispositivo_invalido';
  end if;
  if char_length(btrim(coalesce(p_label, ''))) < 1
     or char_length(p_label) > 80 then
    raise exception 'dispositivo_invalido';
  end if;
  if v_platform not in ('android', 'ios', 'web') then
    v_platform := 'unknown';
  end if;

  select not exists (
    select 1 from public.user_devices where user_id = v_uid
  ) into v_first;

  select not exists (
    select 1 from public.user_devices
    where user_id = v_uid and device_id = p_device_id
  ) into v_new;

  insert into public.user_devices (user_id, device_id, label, platform)
  values (v_uid, p_device_id, btrim(p_label), v_platform)
  on conflict (user_id, device_id) do update
    set label = excluded.label,
        platform = excluded.platform,
        last_seen_at = now();

  if v_new and not v_first then
    if coalesce((
      select security_alerts from public.notification_preferences
      where user_id = v_uid
    ), true) then
      insert into public.notifications (user_id, type, title, body, data)
      values (
        v_uid,
        'security_alert',
        'Novo acesso a conta',
        'Um novo dispositivo acessou sua conta.',
        jsonb_build_object('route', '/security')
      );
    end if;
  end if;

  return jsonb_build_object('is_new', v_new, 'is_first', v_first);
end;
$$;
grant execute on function public.register_device_session(text, text, text)
  to authenticated;

create or replace function public.delete_my_device(p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.user_devices
  where user_id = auth.uid() and device_id = p_device_id;
  return jsonb_build_object('removed', true);
end;
$$;
grant execute on function public.delete_my_device(text) to authenticated;
