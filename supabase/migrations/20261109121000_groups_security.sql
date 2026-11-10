-- Bloco 1 (seguranca de grupos): funcoes de permissao, RLS e RPCs.

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
  );
$$;
grant execute on function public.is_verified_user(uuid) to authenticated;

-- @@

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
  );
$$;
grant execute on function public.is_group_member(uuid, uuid) to authenticated;

-- @@

create or replace function public.has_group_permission(g uuid, p text, u uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
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
  );
$$;
grant execute on function public.has_group_permission(uuid, text, uuid) to authenticated;

-- @@

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

-- @@
-- RLS

drop policy if exists "groups_select_visible" on public.groups;
create policy "groups_select_visible" on public.groups
  for select to authenticated using (public.can_view_group(id));

drop policy if exists "group_members_select_visible" on public.group_members;
create policy "group_members_select_visible" on public.group_members
  for select to authenticated using (public.can_view_group(group_id));

drop policy if exists "group_roles_select_visible" on public.group_roles;
create policy "group_roles_select_visible" on public.group_roles
  for select to authenticated using (public.can_view_group(group_id));

drop policy if exists "group_member_roles_select_visible" on public.group_member_roles;
create policy "group_member_roles_select_visible" on public.group_member_roles
  for select to authenticated
  using (public.can_view_group(group_id) or user_id = auth.uid());

drop policy if exists "group_followers_select" on public.group_followers;
create policy "group_followers_select" on public.group_followers
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_group_member(group_id, auth.uid())
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "group_invites_select_manager" on public.group_invites;
create policy "group_invites_select_manager" on public.group_invites
  for select to authenticated
  using (
    public.has_group_permission(group_id, 'manage_invites', auth.uid())
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "group_audit_select_manager" on public.group_audit_events;
create policy "group_audit_select_manager" on public.group_audit_events
  for select to authenticated
  using (
    public.has_group_permission(group_id, 'manage_group', auth.uid())
    or public.is_admin_user(auth.uid())
  );

-- @@
-- Auditoria

create or replace function public.group_audit(
  g uuid,
  a text,
  t text,
  tid uuid,
  meta jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.group_audit_events
    (group_id, actor_id, action, target_table, target_id, metadata)
  values (g, auth.uid(), a, t, tid, meta);
$$;

-- @@
-- RPCs

create or replace function public.create_group(
  p_name text,
  p_description text default null,
  p_category text default 'outros',
  p_campus text default 'ViÃ§osa',
  p_course text default null,
  p_visibility text default 'private'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_owner_role uuid;
  v_member_role uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then raise exception 'diretrizes_necessarias'; end if;
  if not public.is_profile_complete(auth.uid()) then raise exception 'perfil_incompleto'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'visibilidade invalida'; end if;
  if char_length(btrim(p_name)) < 3 or char_length(btrim(p_name)) > 80 then raise exception 'nome invalido'; end if;

  if (select count(*) from public.groups g
      where g.created_by = auth.uid()
        and g.created_at > now() - interval '24 hours') >= 3 then
    raise exception 'limite_de_grupos';
  end if;

  insert into public.groups
    (name, description, category, campus, course, visibility,
     public_approval, is_official, owner_id, created_by, updated_by)
  values (
    btrim(p_name),
    p_description,
    coalesce(btrim(p_category), 'outros'),
    coalesce(btrim(p_campus), 'ViÃ§osa'),
    p_course,
    p_visibility,
    case when p_visibility = 'public' then 'pending' else 'none' end,
    false,
    auth.uid(),
    auth.uid(),
    auth.uid()
  )
  returning id into v_group;

  insert into public.group_members (group_id, user_id, status)
  values (v_group, auth.uid(), 'active');

  insert into public.group_roles
    (group_id, name, permissions, is_system, rank, created_by, updated_by)
  values (
    v_group, 'Dono',
    array['manage_group','manage_roles','manage_members','manage_invites',
          'post_as_group','moderate_content'],
    true, 100, auth.uid(), auth.uid()
  )
  returning id into v_owner_role;

  insert into public.group_roles
    (group_id, name, permissions, is_system, rank, created_by, updated_by)
  values (v_group, 'Membro', array[]::text[], false, 0, auth.uid(), auth.uid())
  returning id into v_member_role;

  insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
  values (v_group, auth.uid(), v_owner_role, auth.uid());

  perform public.group_audit(
    v_group, 'create_group', 'groups', v_group,
    jsonb_build_object('name', btrim(p_name), 'visibility', p_visibility)
  );

  return jsonb_build_object('id', v_group);
end;
$$;
grant execute on function public.create_group(text, text, text, text, text, text) to authenticated;

-- @@

create or replace function public.update_group(
  p_group_id uuid,
  p_name text,
  p_description text default null,
  p_category text default null,
  p_campus text default null,
  p_course text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_group', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if char_length(btrim(p_name)) < 3 or char_length(btrim(p_name)) > 80 then
    raise exception 'nome invalido';
  end if;

  update public.groups
  set name = btrim(p_name),
      description = p_description,
      category = coalesce(btrim(p_category), category),
      campus = coalesce(btrim(p_campus), campus),
      course = p_course,
      updated_by = auth.uid(),
      updated_at = now()
  where id = p_group_id;

  perform public.group_audit(
    p_group_id, 'update_group', 'groups', p_group_id,
    jsonb_build_object('name', btrim(p_name))
  );
end;
$$;
grant execute on function public.update_group(uuid, text, text, text, text, text) to authenticated;

-- @@

create or replace function public.request_public_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_group', auth.uid()) then
    raise exception 'forbidden';
  end if;

  if exists (
    select 1 from public.groups g
    where g.id <> p_group_id
      and g.visibility = 'public'
      and g.archived_at is null
      and g.name_normalized = (
        select name_normalized from public.groups where id = p_group_id
      )
  ) then
    raise exception 'nome_publico_em_uso';
  end if;

  update public.groups
  set visibility = 'public',
      public_approval = 'pending',
      is_official = false,
      updated_by = auth.uid(),
      updated_at = now()
  where id = p_group_id;

  perform public.group_audit(p_group_id, 'request_public', 'groups', p_group_id);
end;
$$;
grant execute on function public.request_public_group(uuid) to authenticated;

-- @@

create or replace function public.admin_review_group(
  p_group_id uuid,
  p_approve boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.groups
  set public_approval = case when p_approve then 'approved' else 'rejected' end,
      is_official = p_approve,
      updated_by = auth.uid(),
      updated_at = now()
  where id = p_group_id;

  perform public.group_audit(
    p_group_id,
    case when p_approve then 'approve_group' else 'reject_group' end,
    'groups', p_group_id, jsonb_build_object('note', p_note)
  );

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    case when p_approve then 'approve_group' else 'reject_group' end,
    null,
    jsonb_build_object('group_id', p_group_id, 'note', p_note)
  );
end;
$$;
grant execute on function public.admin_review_group(uuid, boolean, text) to authenticated;

-- @@

create or replace function public.join_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then raise exception 'diretrizes_necessarias'; end if;

  if not exists (
    select 1 from public.groups g
    where g.id = p_group_id
      and g.archived_at is null
      and g.visibility = 'public'
      and g.public_approval = 'approved'
      and g.is_official
  ) then raise exception 'grupo_indisponivel'; end if;

  insert into public.group_members (group_id, user_id, status)
  values (p_group_id, auth.uid(), 'active')
  on conflict (group_id, user_id)
  do update set status = 'active', updated_at = now();

  select r.id into v_role
  from public.group_roles r
  where r.group_id = p_group_id and lower(r.name) = 'membro' and not r.is_system
  order by r.rank
  limit 1;

  if v_role is not null then
    insert into public.group_member_roles (group_id, user_id, role_id)
    values (p_group_id, auth.uid(), v_role)
    on conflict (group_id, user_id, role_id) do nothing;
  end if;

  perform public.group_audit(p_group_id, 'join_group', 'group_members', auth.uid());
end;
$$;
grant execute on function public.join_group(uuid) to authenticated;

-- @@

create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.groups g where g.id = p_group_id and g.owner_id = auth.uid()
  ) then
    raise exception 'dono_nao_pode_sair';
  end if;

  update public.group_members
  set status = 'left', updated_at = now()
  where group_id = p_group_id and user_id = auth.uid() and status = 'active';

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = auth.uid();

  perform public.group_audit(p_group_id, 'leave_group', 'group_members', auth.uid());
end;
$$;
grant execute on function public.leave_group(uuid) to authenticated;

-- @@

create or replace function public.follow_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  if not exists (
    select 1 from public.groups g
    where g.id = p_group_id
      and g.archived_at is null
      and g.visibility = 'public'
      and g.public_approval = 'approved'
      and g.is_official
  ) then raise exception 'grupo_indisponivel'; end if;

  insert into public.group_followers (group_id, user_id)
  values (p_group_id, auth.uid())
  on conflict (group_id, user_id) do nothing;
end;
$$;
grant execute on function public.follow_group(uuid) to authenticated;

create or replace function public.unfollow_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.group_followers
  where group_id = p_group_id and user_id = auth.uid();
end;
$$;
grant execute on function public.unfollow_group(uuid) to authenticated;

-- @@

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
begin
  if not public.has_group_permission(p_group_id, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if char_length(btrim(p_name)) < 1 or char_length(btrim(p_name)) > 40 then
    raise exception 'nome invalido';
  end if;

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
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

-- @@

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

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
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

create or replace function public.delete_group_role(p_role_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select group_id into v_group from public.group_roles where id = p_role_id;
  if v_group is null then raise exception 'cargo inexistente'; end if;
  if not public.has_group_permission(v_group, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if exists (select 1 from public.group_roles where id = p_role_id and is_system) then
    raise exception 'cargo_sistema';
  end if;

  delete from public.group_roles where id = p_role_id;

  perform public.group_audit(v_group, 'delete_role', 'group_roles', p_role_id);
end;
$$;
grant execute on function public.delete_group_role(uuid) to authenticated;

-- @@

create or replace function public.assign_group_role(
  p_group_id uuid,
  p_user_id uuid,
  p_role_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if p_user_id = auth.uid() then raise exception 'nao_pode_se_atribuir'; end if;
  if exists (select 1 from public.group_roles r where r.id = p_role_id and r.is_system) then
    raise exception 'cargo_sistema';
  end if;
  if not exists (
    select 1 from public.group_roles r where r.id = p_role_id and r.group_id = p_group_id
  ) then raise exception 'cargo_de_outro_grupo'; end if;
  if not exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_user_id and m.status = 'active'
  ) then raise exception 'usuario_nao_membro'; end if;

  insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
  values (p_group_id, p_user_id, p_role_id, auth.uid())
  on conflict (group_id, user_id, role_id) do nothing;

  perform public.group_audit(
    p_group_id, 'assign_role', 'group_member_roles', p_role_id,
    jsonb_build_object('user', p_user_id)
  );
end;
$$;
grant execute on function public.assign_group_role(uuid, uuid, uuid) to authenticated;

-- @@

create or replace function public.remove_group_role(
  p_group_id uuid,
  p_user_id uuid,
  p_role_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;

  if exists (
    select 1 from public.groups g
    join public.group_roles r on r.id = p_role_id
    where g.id = p_group_id and r.group_id = p_group_id and r.is_system
      and g.owner_id = p_user_id
  ) then raise exception 'cargo_do_dono'; end if;

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = p_user_id and role_id = p_role_id;

  perform public.group_audit(
    p_group_id, 'remove_role', 'group_member_roles', p_role_id,
    jsonb_build_object('user', p_user_id)
  );
end;
$$;
grant execute on function public.remove_group_role(uuid, uuid, uuid) to authenticated;

-- @@

create or replace function public.set_role_profile_visibility(
  p_role_id uuid,
  p_visible boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select r.group_id into v_group from public.group_roles r where r.id = p_role_id;
  if v_group is null then raise exception 'cargo inexistente'; end if;

  if not exists (
    select 1 from public.group_member_roles mr
    where mr.role_id = p_role_id and mr.user_id = auth.uid()
  ) then raise exception 'cargo_nao_atribuido'; end if;

  if p_visible then
    if not exists (
      select 1 from public.groups g
      where g.id = v_group
        and g.visibility = 'public'
        and g.public_approval = 'approved'
        and g.is_official
    ) then raise exception 'grupo_nao_publico_verificado'; end if;
  end if;

  update public.group_member_roles
  set show_on_profile = p_visible
  where role_id = p_role_id and user_id = auth.uid();
end;
$$;
grant execute on function public.set_role_profile_visibility(uuid, boolean) to authenticated;

-- @@

create or replace function public.create_group_invite(
  p_group_id uuid,
  p_expires_at timestamptz,
  p_max_uses int default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_hash text;
  v_id uuid;
begin
  if not public.has_group_permission(p_group_id, 'manage_invites', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if p_max_uses < 1 or p_max_uses > 100 then raise exception 'usos_invalidos'; end if;
  if p_expires_at <= now() then raise exception 'validade_invalida'; end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');

  insert into public.group_invites (group_id, token_hash, expires_at, max_uses, created_by)
  values (p_group_id, v_hash, p_expires_at, p_max_uses, auth.uid())
  returning id into v_id;

  perform public.group_audit(
    p_group_id, 'create_invite', 'group_invites', v_id,
    jsonb_build_object('max_uses', p_max_uses, 'expires_at', p_expires_at)
  );

  return jsonb_build_object(
    'id', v_id,
    'token', v_token,
    'expires_at', p_expires_at,
    'max_uses', p_max_uses
  );
end;
$$;
grant execute on function public.create_group_invite(uuid, timestamptz, int) to authenticated;

-- @@

create or replace function public.revoke_group_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select group_id into v_group from public.group_invites where id = p_invite_id;
  if v_group is null then raise exception 'convite inexistente'; end if;
  if not public.has_group_permission(v_group, 'manage_invites', auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.group_invites set revoked_at = now()
  where id = p_invite_id and revoked_at is null;

  perform public.group_audit(v_group, 'revoke_invite', 'group_invites', p_invite_id);
end;
$$;
grant execute on function public.revoke_group_invite(uuid) to authenticated;

-- @@

create or replace function public.redeem_group_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_invite public.group_invites%rowtype;
  v_group uuid;
  v_role uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then raise exception 'diretrizes_necessarias'; end if;
  if p_token is null or length(p_token) = 0 then raise exception 'token invalido'; end if;

  v_hash := encode(extensions.digest(p_token, 'sha256'), 'hex');

  select * into v_invite
  from public.group_invites
  where token_hash = v_hash
  for update;

  if v_invite.id is null then raise exception 'convite invalido'; end if;
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

  update public.group_invites set used_count = used_count + 1 where id = v_invite.id;

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
    v_group, 'redeem_invite', 'group_members', auth.uid(),
    jsonb_build_object('invite', v_invite.id)
  );

  return v_group;
end;
$$;
grant execute on function public.redeem_group_invite(text) to authenticated;

-- @@

create or replace function public.admin_group_moderate(
  p_group_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'forbidden'; end if;

  if p_action = 'hide' then
    update public.groups
    set under_review = true, updated_by = auth.uid(), updated_at = now()
    where id = p_group_id;
  elsif p_action = 'restore' then
    update public.groups
    set under_review = false, updated_by = auth.uid(), updated_at = now()
    where id = p_group_id;
  elsif p_action = 'archive' then
    update public.groups
    set archived_at = now(), updated_by = auth.uid(), updated_at = now()
    where id = p_group_id;
  else
    raise exception 'acao invalida';
  end if;

  perform public.group_audit(
    p_group_id, 'moderate_' || p_action, 'groups', p_group_id
  );

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(), 'moderate_group_' || p_action, null,
    jsonb_build_object('group_id', p_group_id)
  );
end;
$$;
grant execute on function public.admin_group_moderate(uuid, text) to authenticated;
