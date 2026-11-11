-- Hardening de seguranca (1.0.14): perfis, conexoes, conversas, denuncias,
-- feeds, helpers, tempo do servidor e superficies legadas.

-- 1) Perfis: cliente nao pode se auto-verificar, auto-desbanir ou limpar revisao.

drop policy if exists "profiles_insert_own" on public.profiles;

create or replace function public.guard_profile_sensitive()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
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
  return new;
end;
$$;

drop trigger if exists profiles_guard_sensitive on public.profiles;
create trigger profiles_guard_sensitive
before insert or update on public.profiles
for each row execute function public.guard_profile_sensitive();

-- @@

-- 2) Conexoes: insert somente pendente; aceite apenas via RPC.

drop policy if exists "connections_insert_own" on public.connections;
create policy "connections_insert_own" on public.connections
  for insert to authenticated
  with check (requester_id = auth.uid() and status = 'pending');

drop policy if exists "connections_update_addressee" on public.connections;

-- @@

-- 3) Conversas: sem conversa aceita com estranhos; historico escondido apos bloqueio.

create or replace function public.start_conversation(other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if other_user = auth.uid() then
    raise exception 'cannot start conversation with yourself';
  end if;
  if not public.is_active_user(auth.uid()) or not public.is_active_user(other_user) then
    raise exception 'conta_inativa';
  end if;
  if public.is_blocked(auth.uid(), other_user) then raise exception 'blocked'; end if;
  if not public.is_connection(auth.uid(), other_user) then
    raise exception 'use_message_request';
  end if;

  select c.id into conv_id
  from public.conversations c
  join public.conversation_participants p1
    on p1.conversation_id = c.id and p1.user_id = auth.uid()
  join public.conversation_participants p2
    on p2.conversation_id = c.id and p2.user_id = other_user
  limit 1;

  if conv_id is not null then
    update public.conversations set status = 'accepted' where id = conv_id;
    return conv_id;
  end if;

  insert into public.conversations (status, initiator_id)
  values ('accepted', auth.uid())
  returning id into conv_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values (conv_id, auth.uid()), (conv_id, other_user);
  return conv_id;
end;
$$;
grant execute on function public.start_conversation(uuid) to authenticated;

drop policy if exists "conversations_update_recipient" on public.conversations;

create or replace function public.respond_message_request(
  p_conversation_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_initiator uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select initiator_id into v_initiator
  from public.conversations
  where id = p_conversation_id;

  if v_initiator is null then raise exception 'conversation not found'; end if;
  if v_initiator = auth.uid() then raise exception 'not allowed'; end if;
  if not public.is_conversation_participant(p_conversation_id) then
    raise exception 'not allowed';
  end if;
  if public.conversation_has_block(p_conversation_id) then
    raise exception 'blocked';
  end if;

  update public.conversations
  set status = case when p_accept then 'accepted' else 'declined' end,
      declined_at = case when p_accept then null else now() end
  where id = p_conversation_id
    and status = 'pending';

  if not found then raise exception 'request not found'; end if;

  return jsonb_build_object(
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;
grant execute on function public.respond_message_request(uuid, boolean) to authenticated;

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
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

-- 4) Denuncias: autor real, sem duplicata, limite e auto-hide com 3 denunciantes.

delete from public.reports a
using public.reports b
where a.target_id is not null
  and b.target_id is not null
  and a.reporter_id = b.reporter_id
  and a.target_type = b.target_type
  and a.target_id = b.target_id
  and a.ctid > b.ctid;

delete from public.reports a
using public.reports b
where a.target_type = 'profile'
  and b.target_type = 'profile'
  and a.reporter_id = b.reporter_id
  and a.reported_user_id = b.reported_user_id
  and a.ctid > b.ctid;

create unique index if not exists reports_reporter_target_unique
  on public.reports (reporter_id, target_type, target_id)
  where target_id is not null;

create unique index if not exists reports_reporter_profile_unique
  on public.reports (reporter_id, reported_user_id)
  where target_type = 'profile';

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
begin
  if new.target_type = 'post' then
    select user_id, content into v_author, v_content
    from public.posts where id = new.target_id;
  elsif new.target_type = 'comment' then
    select user_id, content into v_author, v_content
    from public.comments where id = new.target_id;
  elsif new.target_type = 'message' then
    select sender_id, content into v_author, v_content
    from public.messages where id = new.target_id;
  elsif new.target_type = 'material' then
    select author_id,
           coalesce(title, '') || ' ' || coalesce(description, '')
      into v_author, v_content
    from public.study_materials where id = new.target_id;
  elsif new.target_type = 'profile' then
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

drop trigger if exists reports_validate_target on public.reports;
create trigger reports_validate_target
before insert on public.reports
for each row execute function public.validate_report_target();

create or replace function public.handle_report_autohide()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  severe boolean;
  v_distinct int;
begin
  severe := new.category in (
    'intolerancia_discriminacao',
    'violencia_ameaca',
    'conteudo_sexual_explicito',
    'imagem_nao_consentida',
    'menor_de_idade'
  );

  if not severe then
    return new;
  end if;

  if new.target_type = 'profile' then
    select count(distinct reporter_id) into v_distinct
    from public.reports
    where target_type = 'profile'
      and reported_user_id = new.reported_user_id
      and status in ('open', 'reviewing')
      and category in (
        'intolerancia_discriminacao',
        'violencia_ameaca',
        'conteudo_sexual_explicito',
        'imagem_nao_consentida',
        'menor_de_idade'
      );

    if v_distinct >= 3 then
      update public.profiles set profile_under_review = true
      where id = new.reported_user_id;
    end if;
    return new;
  end if;

  if new.target_id is null then
    return new;
  end if;

  select count(distinct reporter_id) into v_distinct
  from public.reports
  where target_type = new.target_type
    and target_id = new.target_id
    and status in ('open', 'reviewing')
    and category in (
      'intolerancia_discriminacao',
      'violencia_ameaca',
      'conteudo_sexual_explicito',
      'imagem_nao_consentida',
      'menor_de_idade'
    );

  if v_distinct < 3 then
    return new;
  end if;

  if new.target_type = 'post' then
    update public.posts set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'comment' then
    update public.comments set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'message' then
    update public.messages set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'material' then
    update public.study_materials
    set status = 'hidden', hidden_at = now()
    where id = new.target_id and hidden_at is null;
  end if;

  return new;
end;
$$;

-- @@

-- 5) Feeds e visao de post: autor ativo e fora de revisao.

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
      and not public.is_blocked(auth.uid(), po.user_id)
      and (
        po.user_id = auth.uid()
        or (po.group_id is not null and public.can_view_group(po.group_id))
        or (po.group_id is null and pr.profile_private = false and po.visibility = 'public')
        or (po.group_id is null and public.is_connection(auth.uid(), po.user_id))
      )
  );
$$;

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

-- 6) Superficies e utilitarios.

create or replace function public.group_stats(p_group_id uuid)
returns table (member_count bigint, follower_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select
    (select count(*) from public.group_members m
     where m.group_id = p_group_id and m.status = 'active'),
    (select count(*) from public.group_followers f
     where f.group_id = p_group_id)
  where public.can_view_group(p_group_id);
$$;
grant execute on function public.group_stats(uuid) to authenticated;

revoke all on function public.create_group_invite(uuid, timestamptz, int)
  from public, anon, authenticated;
revoke all on function public.redeem_group_invite(text)
  from public, anon, authenticated;
revoke all on function public.group_audit(uuid, text, text, uuid, jsonb)
  from public, anon, authenticated;

update public.group_invites
set revoked_at = now()
where target_user_id is null and revoked_at is null;

-- @@

-- 7) Helpers: sem oraculo sobre outros usuarios.

create or replace function public.is_verified_user(uid uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid
      and p.account_status = 'active'
      and (
        p.verification_status = 'verified'
        or lower(coalesce(p.ufv_email, '')) like '%@alunos.ufv.br'
      )
      and (uid = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;
grant execute on function public.is_verified_user(uuid) to authenticated;

create or replace function public.is_profile_complete(user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = user_id
      and p.display_name is not null and length(btrim(p.display_name)) > 0
      and p.course is not null and length(btrim(p.course)) > 0
      and p.campus is not null and length(btrim(p.campus)) > 0
      and p.avatar_url is not null and length(btrim(p.avatar_url)) > 0
      and (user_id = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;

create or replace function public.has_accepted_guidelines(uid uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.consents c
    where c.user_id = uid
      and c.type = 'community_guidelines'
      and c.accepted = true
      and (uid = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;
grant execute on function public.has_accepted_guidelines(uuid) to authenticated;

create or replace function public.is_group_member(g uuid, u uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = g and m.user_id = u and m.status = 'active'
      and (u = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;

create or replace function public.has_group_permission(g uuid, p text, u uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    (u = auth.uid() or public.is_admin_user(auth.uid()))
    and (
      exists (
        select 1 from public.groups gr where gr.id = g and gr.owner_id = u
      )
      or exists (
        select 1
        from public.group_members m
        join public.group_member_roles mr
          on mr.group_id = m.group_id and mr.user_id = m.user_id
        join public.group_roles r on r.id = mr.role_id
        where m.group_id = g and m.user_id = u and m.status = 'active'
          and p = any(r.permissions)
      )
    );
$$;
grant execute on function public.has_group_permission(uuid, text, uuid) to authenticated;

create or replace function public.is_connection(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.connections
    where status = 'accepted'
      and (
        (requester_id = a and addressee_id = b)
        or (requester_id = b and addressee_id = a)
      )
      and (a = auth.uid() or b = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.blocks
    where ((blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a))
      and (a = auth.uid() or b = auth.uid() or public.is_admin_user(auth.uid()))
  );
$$;

-- @@

-- 8) Cargos: nao conceder permissao que o criador nao possui.

create or replace function public.create_group_role(
  p_group_id uuid,
  p_name text,
  p_permissions text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_perm text;
  v_is_owner boolean;
begin
  if not public.has_group_permission(p_group_id, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if char_length(btrim(p_name)) < 1 or char_length(btrim(p_name)) > 40 then
    raise exception 'nome invalido';
  end if;

  select exists (
    select 1 from public.groups g
    where g.id = p_group_id and g.owner_id = auth.uid()
  ) into v_is_owner;

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
    end if;
    if not v_is_owner
       and not public.has_group_permission(p_group_id, v_perm, auth.uid()) then
      raise exception 'permissao_nao_permitida';
    end if;
  end loop;

  insert into public.group_roles (group_id, name, permissions, created_by, updated_by)
  values (p_group_id, btrim(p_name), coalesce(p_permissions, '{}'), auth.uid(), auth.uid())
  returning id into v_id;

  perform public.group_audit(
    p_group_id, 'create_role', 'group_roles', v_id,
    jsonb_build_object('name', btrim(p_name))
  );

  return v_id;
end;
$$;
grant execute on function public.create_group_role(uuid, text, text[]) to authenticated;

create or replace function public.update_group_role(
  p_role_id uuid,
  p_name text,
  p_permissions text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_perm text;
  v_is_owner boolean;
begin
  select group_id into v_group from public.group_roles where id = p_role_id;
  if v_group is null then raise exception 'cargo inexistente'; end if;
  if not public.has_group_permission(v_group, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if exists (select 1 from public.group_roles where id = p_role_id and is_system) then
    raise exception 'cargo_sistema';
  end if;
  if char_length(btrim(p_name)) < 1 or char_length(btrim(p_name)) > 40 then
    raise exception 'nome invalido';
  end if;

  select exists (
    select 1 from public.groups g
    where g.id = v_group and g.owner_id = auth.uid()
  ) into v_is_owner;

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
    end if;
    if not v_is_owner
       and not public.has_group_permission(v_group, v_perm, auth.uid()) then
      raise exception 'permissao_nao_permitida';
    end if;
  end loop;

  update public.group_roles
  set name = btrim(p_name),
      permissions = coalesce(p_permissions, '{}'),
      updated_by = auth.uid(),
      updated_at = now()
  where id = p_role_id;

  perform public.group_audit(
    v_group, 'update_role', 'group_roles', p_role_id,
    jsonb_build_object('name', btrim(p_name))
  );
end;
$$;
grant execute on function public.update_group_role(uuid, text, text[]) to authenticated;

-- @@

-- 9) Aceite de convite: grupo nao arquivado.

create or replace function public.accept_group_invite(p_invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.group_invites%rowtype;
  v_group uuid;
  v_role uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then
    raise exception 'diretrizes_necessarias';
  end if;

  select * into v_invite
  from public.group_invites
  where id = p_invite_id
  for update;

  if v_invite.id is null then raise exception 'convite invalido'; end if;
  if v_invite.target_user_id is distinct from auth.uid() then
    raise exception 'convite de outro usuario';
  end if;
  if v_invite.revoked_at is not null then raise exception 'convite revogado'; end if;
  if v_invite.expires_at <= now() then raise exception 'convite expirado'; end if;
  if v_invite.used_count >= v_invite.max_uses then raise exception 'convite esgotado'; end if;

  v_group := v_invite.group_id;

  if not exists (
    select 1 from public.groups g
    where g.id = v_group and g.archived_at is null
  ) then raise exception 'grupo_indisponivel'; end if;

  if exists (
    select 1 from public.group_members m
    where m.group_id = v_group and m.user_id = auth.uid() and m.status = 'active'
  ) then
    return v_group;
  end if;

  update public.group_invites set used_count = used_count + 1
  where id = p_invite_id;

  insert into public.group_members (group_id, user_id, status, invited_by)
  values (v_group, auth.uid(), 'active', v_invite.created_by)
  on conflict (group_id, user_id)
  do update set status = 'active', updated_at = now();

  select r.id into v_role
  from public.group_roles r
  where r.group_id = v_group and lower(r.name) = 'membro' and not r.is_system
  order by r.rank
  limit 1;

  if v_role is not null then
    insert into public.group_member_roles (group_id, user_id, role_id)
    values (v_group, auth.uid(), v_role)
    on conflict (group_id, user_id, role_id) do nothing;
  end if;

  perform public.group_audit(
    v_group, 'accept_invite', 'group_members', auth.uid(),
    jsonb_build_object('invite', p_invite_id)
  );

  return v_group;
end;
$$;
grant execute on function public.accept_group_invite(uuid) to authenticated;

-- @@

-- 10) Device token: nao reatribuir token de outro usuario.

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_token is null or length(btrim(p_token)) < 20 then
    raise exception 'invalid token';
  end if;

  insert into public.device_tokens (user_id, token, platform, last_seen_at, updated_at)
  values (
    auth.uid(),
    btrim(p_token),
    coalesce(nullif(btrim(p_platform), ''), 'android'),
    now(),
    now()
  )
  on conflict (token) do update
  set platform = excluded.platform,
      last_seen_at = now(),
      updated_at = now()
  where public.device_tokens.user_id = excluded.user_id;
end;
$$;
grant execute on function public.register_device_token(text, text) to authenticated;

-- @@

-- 11) Data/hora do servidor.

create or replace function public.force_server_created_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin_user(auth.uid()) then
    new.created_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists posts_force_created_at on public.posts;
create trigger posts_force_created_at
before insert on public.posts
for each row execute function public.force_server_created_at();

drop trigger if exists comments_force_created_at on public.comments;
create trigger comments_force_created_at
before insert on public.comments
for each row execute function public.force_server_created_at();

drop trigger if exists messages_force_created_at on public.messages;
create trigger messages_force_created_at
before insert on public.messages
for each row execute function public.force_server_created_at();
