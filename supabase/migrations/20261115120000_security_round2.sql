-- Rodada 2 de hardening (findings ALTO/MEDIO 1-8).

-- 1) Guard de perfil: contextos de servidor permitidos; caminho de avatar/fotos.

create or replace function public.guard_profile_sensitive()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if auth.uid() is null or public.is_admin_user(auth.uid()) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.verification_status := 'unverified';
    new.account_status := 'active';
    new.profile_under_review := false;
    new.ufv_email := null;
    new.cpf_hash := null;
    new.created_at := now();
    return new;
  end if;

  new.verification_status := old.verification_status;
  new.account_status := old.account_status;
  new.profile_under_review := old.profile_under_review;
  new.ufv_email := old.ufv_email;
  new.cpf_hash := old.cpf_hash;
  new.birth_date := old.birth_date;
  new.created_at := old.created_at;
  new.updated_at := now();

  if new.avatar_url is distinct from old.avatar_url
     and new.avatar_url is not null
     and new.avatar_url not like auth.uid()::text || '/%' then
    raise exception 'caminho_invalido';
  end if;

  if new.photos is distinct from old.photos and new.photos is not null then
    if exists (
      select 1 from unnest(new.photos) x
      where x not like auth.uid()::text || '/%'
    ) then
      raise exception 'caminho_invalido';
    end if;
  end if;

  return new;
end;
$$;

-- @@

-- 2) Conexoes: insert somente via RPC; alvo ativo; sem notificacao para bloqueado.

drop policy if exists "connections_insert_own" on public.connections;

drop policy if exists "connections_select_own" on public.connections;
create policy "connections_select_own" on public.connections
  for select to authenticated
  using (
    (requester_id = auth.uid() or addressee_id = auth.uid())
    and public.is_active_user(auth.uid())
  );

create or replace function public.send_connection_request(target_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing record;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if target_user = auth.uid() then raise exception 'cannot connect to yourself'; end if;
  if not public.is_active_user(target_user) then raise exception 'destinatario_inativo'; end if;
  if not public.is_profile_complete(auth.uid()) then raise exception 'profile incomplete'; end if;
  if public.is_blocked(auth.uid(), target_user) then raise exception 'blocked'; end if;

  select requester_id, addressee_id, status into existing
  from public.connections
  where (requester_id = auth.uid() and addressee_id = target_user)
     or (requester_id = target_user and addressee_id = auth.uid())
  limit 1;

  if existing.requester_id is not null then
    return jsonb_build_object(
      'status', existing.status,
      'requester', existing.requester_id
    );
  end if;

  insert into public.connections (requester_id, addressee_id, status)
  values (auth.uid(), target_user, 'pending');

  return jsonb_build_object('status', 'pending', 'requester', auth.uid());
end;
$$;
grant execute on function public.send_connection_request(uuid) to authenticated;

create or replace function public.notify_connection_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_blocked(new.requester_id, new.addressee_id) then
    return new;
  end if;

  if new.status = 'pending' then
    perform public.enqueue_notification(
      new.addressee_id,
      'connection_request',
      'Nova solicitacao de conexao',
      'Voce recebeu uma solicitacao de conexao.',
      jsonb_build_object(
        'route', '/chats?tab=connections',
        'requester_id', new.requester_id
      )
    );
  end if;

  return new;
end;
$$;

-- @@

-- 3) Conta inativa nao le nem interage.

create or replace function public.can_view_group(g uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.groups gr
    where gr.id = g
      and gr.archived_at is null
      and public.is_active_user(auth.uid())
      and (
        public.is_admin_user(auth.uid())
        or public.is_group_member(g, auth.uid())
        or (
          gr.visibility = 'public'
          and gr.public_approval = 'approved'
          and gr.is_official
          and gr.under_review = false
        )
      )
  );
$$;
grant execute on function public.can_view_group(uuid) to authenticated;

create or replace function public.can_view_post(post_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.posts po
    join public.profiles pr on pr.id = po.user_id
    where po.id = post_id
      and po.hidden_at is null
      and pr.account_status = 'active'
      and pr.profile_under_review = false
      and public.is_active_user(auth.uid())
      and not public.is_blocked(auth.uid(), po.user_id)
      and (
        po.user_id = auth.uid()
        or (po.group_id is not null and public.can_view_group(po.group_id))
        or (po.group_id is null and pr.profile_private = false and po.visibility = 'public')
        or (po.group_id is null and public.is_connection(auth.uid(), po.user_id))
      )
  );
$$;

drop view if exists public.profiles_public;
create view public.profiles_public as
  select p.id, p.display_name, p.course, p.campus, p.bio, p.prompts,
         p.avatar_url, p.photos, p.interests, p.relationship_style,
         p.verification_status, p.profile_private, p.created_at
  from public.profiles p
  where p.account_status = 'active'
    and p.profile_under_review = false
    and public.is_active_user(auth.uid())
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    );

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;

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
  order by p.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;
grant execute on function public.discover_profiles(int, int, text, text) to authenticated;

create or replace function public.public_group_directory(p_search text default null)
returns table (
  id uuid,
  name text,
  description text,
  category text,
  campus text,
  is_official boolean,
  member_count bigint,
  follower_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  select
    g.id,
    g.name,
    g.description,
    g.category,
    g.campus,
    g.is_official,
    (select count(*) from public.group_members m
     where m.group_id = g.id and m.status = 'active'),
    (select count(*) from public.group_followers f
     where f.group_id = g.id)
  from public.groups g
  where g.visibility = 'public'
    and g.public_approval = 'approved'
    and g.is_official
    and g.under_review = false
    and g.archived_at is null
    and public.is_active_user(auth.uid())
    and (
      p_search is null or btrim(p_search) = ''
      or g.name ilike '%' || p_search || '%'
      or g.category ilike '%' || p_search || '%'
      or g.campus ilike '%' || p_search || '%'
    )
  order by g.name;
$$;
grant execute on function public.public_group_directory(text) to authenticated;

-- @@

-- Feeds: conta inativa nao recebe feed.

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

-- @@

-- Conversas e conexoes: somente contas ativas leem.

drop policy if exists "conversations_select_participant" on public.conversations;
create policy "conversations_select_participant" on public.conversations
  for select to authenticated
  using (
    public.is_conversation_participant(id)
    and public.is_active_user(auth.uid())
  );

drop policy if exists "participants_select_participant" on public.conversation_participants;
create policy "participants_select_participant" on public.conversation_participants
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
  );

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
    and hidden_at is null
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
    and not public.conversation_has_block(conversation_id)
    and not exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id
        and p.user_id = auth.uid()
        and p.cleared_at is not null
        and messages.created_at <= p.cleared_at
    )
    and not exists (
      select 1 from public.message_deletions d
      where d.message_id = messages.id and d.user_id = auth.uid()
    )
  );

-- @@

-- Bloqueio tambem esconde comentarios e curtidas de terceiros.

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select to authenticated
  using (
    public.can_view_post(post_id)
    and hidden_at is null
    and not public.is_blocked(auth.uid(), user_id)
  );

drop policy if exists "likes_select_auth" on public.likes;
create policy "likes_select_auth" on public.likes
  for select to authenticated
  using (
    public.can_view_post(post_id)
    and not public.is_blocked(auth.uid(), user_id)
  );

drop policy if exists "likes_insert_own" on public.likes;
create policy "likes_insert_own" on public.likes
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.is_active_user(auth.uid())
    and public.can_view_post(post_id)
  );

-- @@

-- Denuncias: tempo do servidor, conta ativa e alvo visivel.

create or replace function public.validate_report_target()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
  v_content text;
  v_count int;
  v_post uuid;
  v_conversation uuid;
begin
  if not public.is_active_user(auth.uid()) then
    raise exception 'conta_inativa';
  end if;

  if new.target_type = 'post' then
    if not public.can_view_post(new.target_id) then
      raise exception 'alvo_inacessivel';
    end if;
    select user_id, content into v_author, v_content
    from public.posts where id = new.target_id;
  elsif new.target_type = 'comment' then
    select post_id, user_id, content into v_post, v_author, v_content
    from public.comments where id = new.target_id;
    if v_post is null or not public.can_view_post(v_post) then
      raise exception 'alvo_inacessivel';
    end if;
  elsif new.target_type = 'message' then
    select conversation_id, sender_id, content
      into v_conversation, v_author, v_content
    from public.messages where id = new.target_id;
    if v_conversation is null
       or not public.is_conversation_participant(v_conversation) then
      raise exception 'alvo_inacessivel';
    end if;
  elsif new.target_type = 'material' then
    select author_id,
           coalesce(title, '') || ' ' || coalesce(description, '')
      into v_author, v_content
    from public.study_materials where id = new.target_id;
    if v_author is null or not exists (
      select 1 from public.study_materials m
      where m.id = new.target_id
        and (
          (m.status = 'approved' and m.hidden_at is null)
          or m.author_id = auth.uid()
          or public.is_admin_user(auth.uid())
        )
    ) then
      raise exception 'alvo_inacessivel';
    end if;
  elsif new.target_type = 'profile' then
    if not exists (
      select 1 from public.profiles p
      where p.id = new.reported_user_id and p.account_status = 'active'
    ) then
      raise exception 'alvo_invalido';
    end if;
    v_author := new.reported_user_id;
    v_content := null;
  else
    raise exception 'tipo_invalido';
  end if;

  if v_author is null then raise exception 'alvo_invalido'; end if;

  if new.target_type <> 'profile'
     and new.reported_user_id is distinct from v_author then
    raise exception 'alvo_invalido';
  end if;

  if v_author = new.reporter_id then
    raise exception 'nao_pode_denunciar_a_si';
  end if;

  if new.target_type <> 'profile' then
    new.content_snapshot := left(coalesce(v_content, ''), 500);
  end if;

  select count(*) into v_count
  from public.reports r
  where r.reporter_id = new.reporter_id
    and r.created_at > now() - interval '24 hours';

  if v_count >= 20 then raise exception 'limite_denuncias'; end if;

  return new;
end;
$$;

drop trigger if exists reports_force_created_at on public.reports;
create trigger reports_force_created_at
before insert on public.reports
for each row execute function public.force_server_created_at();
