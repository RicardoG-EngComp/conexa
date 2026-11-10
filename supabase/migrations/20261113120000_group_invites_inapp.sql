-- Convites 100% in-app (direcionados) + remocao de seguidor + notificacao.

alter table public.group_invites
  add column if not exists target_user_id uuid references auth.users(id) on delete cascade;

create index if not exists group_invites_target_idx
  on public.group_invites (target_user_id)
  where target_user_id is not null;

-- @@

create or replace function public.create_group_invite_for_user(
  p_group_id uuid,
  p_target_user_id uuid,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_hash text;
  v_id uuid;
  v_existing uuid;
  v_group_name text;
  v_expires timestamptz := coalesce(p_expires_at, now() + interval '7 days');
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.has_group_permission(p_group_id, 'manage_invites', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if p_target_user_id is null or p_target_user_id = auth.uid() then
    raise exception 'destinatario_invalido';
  end if;
  if not public.is_connection(auth.uid(), p_target_user_id) then
    raise exception 'sem_conexao';
  end if;
  if not public.is_active_user(p_target_user_id) then
    raise exception 'destinatario_inativo';
  end if;
  if v_expires <= now() then raise exception 'validade_invalida'; end if;

  if exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_target_user_id
      and m.status = 'active'
  ) then raise exception 'ja_e_membro'; end if;

  select id into v_existing
  from public.group_invites
  where group_id = p_group_id
    and target_user_id = p_target_user_id
    and revoked_at is null
    and used_count < max_uses
    and expires_at > now()
  order by created_at desc
  limit 1;
  if v_existing is not null then return v_existing; end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');

  select name into v_group_name from public.groups where id = p_group_id;

  insert into public.group_invites
    (group_id, token_hash, expires_at, max_uses, created_by, target_user_id)
  values (p_group_id, v_hash, v_expires, 1, auth.uid(), p_target_user_id)
  returning id into v_id;

  perform public.group_audit(
    p_group_id, 'invite_user', 'group_invites', v_id,
    jsonb_build_object('target_user', p_target_user_id)
  );

  perform public.enqueue_notification(
    p_target_user_id,
    'group_invite',
    'Convite de grupo',
    'Você recebeu um convite para o grupo ' || coalesce(v_group_name, '') || '.',
    jsonb_build_object('route', '/invites', 'group_id', p_group_id, 'invite_id', v_id)
  );

  return v_id;
end;
$$;
grant execute on function public.create_group_invite_for_user(uuid, uuid, timestamptz) to authenticated;

-- @@

create or replace function public.my_group_invites()
returns table (
  invite_id uuid,
  group_id uuid,
  group_name text,
  group_category text,
  group_official boolean,
  inviter_name text,
  expires_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    i.id,
    g.id,
    g.name,
    g.category,
    g.is_official,
    coalesce(p.display_name, 'Alguém'),
    i.expires_at,
    i.created_at
  from public.group_invites i
  join public.groups g on g.id = i.group_id
  left join public.profiles p on p.id = i.created_by
  where i.target_user_id = auth.uid()
    and i.revoked_at is null
    and i.used_count < i.max_uses
    and i.expires_at > now()
    and g.archived_at is null
    and not exists (
      select 1 from public.group_members m
      where m.group_id = i.group_id and m.user_id = auth.uid()
        and m.status = 'active'
    )
  order by i.created_at desc;
$$;
grant execute on function public.my_group_invites() to authenticated;

-- @@

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

create or replace function public.decline_group_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_target uuid;
begin
  select group_id, target_user_id into v_group, v_target
  from public.group_invites where id = p_invite_id;

  if v_group is null then raise exception 'convite invalido'; end if;
  if v_target is distinct from auth.uid() then
    raise exception 'convite de outro usuario';
  end if;

  update public.group_invites set revoked_at = now()
  where id = p_invite_id and revoked_at is null;

  perform public.group_audit(v_group, 'decline_invite', 'group_invites', p_invite_id);
end;
$$;
grant execute on function public.decline_group_invite(uuid) to authenticated;

-- @@

create or replace function public.remove_group_follower(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_members', auth.uid()) then
    raise exception 'forbidden';
  end if;

  delete from public.group_followers
  where group_id = p_group_id and user_id = p_user_id;

  perform public.group_audit(
    p_group_id, 'remove_follower', 'group_followers', p_user_id
  );
end;
$$;
grant execute on function public.remove_group_follower(uuid, uuid) to authenticated;

-- @@
-- Notificacao de convite de grupo

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
    'group_invite'
  ));

alter table public.notification_preferences
  add column if not exists groups boolean not null default true;

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
        else false
      end
      from public.notification_preferences p
      where p.user_id = p_user_id
    ),
    true
  );
$$;

revoke all on function public.notification_type_enabled(uuid, text)
  from anon, authenticated;
