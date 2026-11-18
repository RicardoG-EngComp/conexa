-- Governanca de grupos: cargos de gestao, administradores multiplos e
-- transferencia sem privilegio automatico por owner_id.

create or replace function public.normalize_group_category(p text)
returns text
language sql
immutable
set search_path = public
as $$
  select case public.normalize_group_name(coalesce(p, ''))
    when 'centro academico' then 'Centro Acadêmico'
    when 'atletica' then 'Atlética'
    when 'grupo de estudos' then 'Grupo de Estudos'
    when 'republica' then 'República'
    when 'diretorio academico' then 'Diretório Acadêmico'
    when 'outros' then 'Outros'
    else null
  end;
$$;

alter table public.groups
  drop constraint if exists groups_category_check;
alter table public.groups
  add constraint groups_category_check
  check (category in (
    'Centro Acadêmico', 'Atlética', 'Grupo de Estudos', 'República',
    'Diretório Acadêmico', 'Outros'
  ));

create or replace function public.group_leader_role_name(p_category text)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_category in (
      'Centro Acadêmico', 'República', 'Diretório Acadêmico'
    ) then 'Administração'
    else 'Dono'
  end;
$$;

create or replace function public.is_institutional_group(p_category text)
returns boolean
language sql
immutable
set search_path = public
as $$
  select p_category in (
    'Centro Acadêmico', 'República', 'Diretório Acadêmico'
  );
$$;

create or replace function public.is_group_leader(
  p_group_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.group_members m
    join public.group_member_roles mr
      on mr.group_id = m.group_id and mr.user_id = m.user_id
    join public.group_roles r on r.id = mr.role_id
    where m.group_id = p_group_id
      and m.user_id = p_user_id
      and m.status = 'active'
      and r.is_system
  );
$$;
grant execute on function public.is_group_leader(uuid, uuid) to authenticated;

create or replace function public.group_leader_count(
  p_group_id uuid,
  p_exclude uuid default null
)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(distinct m.user_id)::integer
  from public.group_members m
  join public.group_member_roles mr
    on mr.group_id = m.group_id and mr.user_id = m.user_id
  join public.group_roles r on r.id = mr.role_id
  where m.group_id = p_group_id
    and m.status = 'active'
    and r.is_system
    and (p_exclude is null or m.user_id <> p_exclude);
$$;
revoke all on function public.group_leader_count(uuid, uuid) from public;

-- O dono/administrador nao tem mais privilegio automatico: tudo vem do cargo.
create or replace function public.has_group_permission(
  g uuid,
  p text,
  u uuid default auth.uid()
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    (u = auth.uid() or public.is_admin_user(auth.uid()))
    and exists (
      select 1
      from public.group_members m
      join public.group_member_roles mr
        on mr.group_id = m.group_id and mr.user_id = m.user_id
      join public.group_roles r on r.id = mr.role_id
      where m.group_id = g and m.user_id = u and m.status = 'active'
        and p = any(r.permissions)
    );
$$;
grant execute on function public.has_group_permission(uuid, text, uuid)
  to authenticated;

create or replace function public.create_group(
  p_name text,
  p_description text default null,
  p_category text default 'outros',
  p_campus text default 'Viçosa',
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
  v_leader_role uuid;
  v_member_role uuid;
  v_category text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then raise exception 'diretrizes_necessarias'; end if;
  if not public.is_profile_complete(auth.uid()) then raise exception 'perfil_incompleto'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'visibilidade invalida'; end if;
  if char_length(btrim(p_name)) < 3 or char_length(btrim(p_name)) > 80 then raise exception 'nome invalido'; end if;

  v_category := public.normalize_group_category(p_category);
  if v_category is null then raise exception 'categoria_invalida'; end if;

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
    v_category,
    coalesce(btrim(p_campus), 'Viçosa'),
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
    v_group,
    public.group_leader_role_name(v_category),
    array['manage_group','manage_roles','manage_members','manage_invites',
          'post_as_group','moderate_content'],
    true, 100, auth.uid(), auth.uid()
  )
  returning id into v_leader_role;

  insert into public.group_roles
    (group_id, name, permissions, is_system, rank, created_by, updated_by)
  values (v_group, 'Membro', array[]::text[], false, 0, auth.uid(), auth.uid())
  returning id into v_member_role;

  insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
  values (v_group, auth.uid(), v_leader_role, auth.uid());

  perform public.group_audit(
    v_group, 'create_group', 'groups', v_group,
    jsonb_build_object('name', btrim(p_name), 'visibility', p_visibility)
  );

  return jsonb_build_object('id', v_group);
end;
$$;
grant execute on function public.create_group(text, text, text, text, text, text)
  to authenticated;

-- Criacao/edicao de cargo: quem tem manage_roles so concede permissoes que possui.
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
    raise exception 'nome_invalido';
  end if;

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
    end if;
    if not public.has_group_permission(p_group_id, v_perm, auth.uid()) then
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
grant execute on function public.create_group_role(uuid, text, text[])
  to authenticated;

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
  if v_group is null then raise exception 'cargo_inexistente'; end if;
  if not public.has_group_permission(v_group, 'manage_roles', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if exists (select 1 from public.group_roles where id = p_role_id and is_system) then
    raise exception 'cargo_sistema';
  end if;
  if char_length(btrim(p_name)) < 1 or char_length(btrim(p_name)) > 40 then
    raise exception 'nome_invalido';
  end if;

  foreach v_perm in array coalesce(p_permissions, '{}') loop
    if not public.is_valid_group_permission(v_perm) then
      raise exception 'permissao_invalida';
    end if;
    if not public.has_group_permission(v_group, v_perm, auth.uid()) then
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
grant execute on function public.update_group_role(uuid, text, text[])
  to authenticated;

-- Move a gestao para outro membro ativo.
create or replace function public.transfer_group_leadership(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role uuid;
  v_old_owner uuid;
  v_new_owner uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_admin_user(auth.uid())
     and not public.is_group_leader(p_group_id, auth.uid()) then
    raise exception 'gestao_necessaria';
  end if;

  select owner_id into v_old_owner from public.groups where id = p_group_id;
  if v_old_owner is null then raise exception 'grupo_inexistente'; end if;
  if p_user_id = auth.uid() then raise exception 'mesmo_administrador'; end if;
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id and status = 'active'
  ) then raise exception 'membro_inativo'; end if;

  select id into v_role
  from public.group_roles
  where group_id = p_group_id and is_system
  limit 1;
  if v_role is null then raise exception 'cargo_gestao_ausente'; end if;

  if public.is_group_leader(p_group_id, p_user_id) then
    raise exception 'ja_administrador';
  end if;

  insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
  values (p_group_id, p_user_id, v_role, auth.uid())
  on conflict (group_id, user_id, role_id) do nothing;

  delete from public.group_member_roles
  where group_id = p_group_id and role_id = v_role and user_id <> p_user_id;

  update public.groups
  set owner_id = p_user_id, updated_by = auth.uid(), updated_at = now()
  where id = p_group_id;

  update public.conversations
  set owner_id = p_user_id
  where group_id = p_group_id;

  update public.conversation_participants cp
  set role = 'member'
  from public.conversations c
  where cp.conversation_id = c.id and c.group_id = p_group_id
    and cp.user_id <> p_user_id;

  update public.conversation_participants cp
  set role = 'owner'
  from public.conversations c
  where cp.conversation_id = c.id and c.group_id = p_group_id
    and cp.user_id = p_user_id;

  perform public.group_audit(
    p_group_id, 'transfer_leadership', 'group_members', p_user_id,
    jsonb_build_object('from', v_old_owner, 'to', p_user_id)
  );
end;
$$;
grant execute on function public.transfer_group_leadership(uuid, uuid)
  to authenticated;

-- Em grupos institucionais, mais de um membro pode ter o cargo de administracao.
create or replace function public.add_group_administrator(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role uuid;
  v_category text;
begin
  select category into v_category from public.groups where id = p_group_id;
  if v_category is null then raise exception 'grupo_inexistente'; end if;
  if not public.is_institutional_group(v_category) then
    raise exception 'administracao_unica';
  end if;
  if not public.is_admin_user(auth.uid())
     and not public.is_group_leader(p_group_id, auth.uid()) then
    raise exception 'gestao_necessaria';
  end if;
  if not exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = p_user_id and status = 'active'
  ) then raise exception 'membro_inativo'; end if;

  select id into v_role
  from public.group_roles where group_id = p_group_id and is_system limit 1;
  if v_role is null then raise exception 'cargo_gestao_ausente'; end if;
  if public.is_group_leader(p_group_id, p_user_id) then
    raise exception 'ja_administrador';
  end if;

  insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
  values (p_group_id, p_user_id, v_role, auth.uid())
  on conflict (group_id, user_id, role_id) do nothing;

  perform public.group_audit(
    p_group_id, 'add_administrator', 'group_members', p_user_id
  );
end;
$$;
grant execute on function public.add_group_administrator(uuid, uuid)
  to authenticated;

create or replace function public.remove_group_administrator(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role uuid;
  v_category text;
  v_new_owner uuid;
begin
  select category into v_category from public.groups where id = p_group_id;
  if v_category is null then raise exception 'grupo_inexistente'; end if;
  if not public.is_institutional_group(v_category) then
    raise exception 'administracao_unica';
  end if;
  if not public.is_admin_user(auth.uid())
     and not public.is_group_leader(p_group_id, auth.uid()) then
    raise exception 'gestao_necessaria';
  end if;
  if not public.is_group_leader(p_group_id, p_user_id) then
    raise exception 'nao_administrador';
  end if;
  if public.group_leader_count(p_group_id, p_user_id) = 0 then
    raise exception 'ultimo_administrador';
  end if;

  select id into v_role
  from public.group_roles where group_id = p_group_id and is_system limit 1;

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = p_user_id and role_id = v_role;

  select mr.user_id into v_new_owner
  from public.group_member_roles mr
  join public.group_roles r on r.id = mr.role_id
  join public.group_members m
    on m.group_id = mr.group_id and m.user_id = mr.user_id and m.status = 'active'
  where mr.group_id = p_group_id and r.is_system
  order by mr.assigned_at
  limit 1;

  if v_new_owner is not null then
    update public.groups
    set owner_id = v_new_owner, updated_by = auth.uid(), updated_at = now()
    where id = p_group_id;

    update public.conversations set owner_id = v_new_owner where group_id = p_group_id;
    update public.conversation_participants cp
    set role = 'member'
    from public.conversations c
    where cp.conversation_id = c.id and c.group_id = p_group_id
      and cp.user_id <> v_new_owner;
    update public.conversation_participants cp
    set role = 'owner'
    from public.conversations c
    where cp.conversation_id = c.id and c.group_id = p_group_id
      and cp.user_id = v_new_owner;
  end if;

  perform public.group_audit(
    p_group_id, 'remove_administrator', 'group_members', p_user_id
  );
end;
$$;
grant execute on function public.remove_group_administrator(uuid, uuid)
  to authenticated;

create or replace function public.leave_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_owner uuid;
begin
  if public.is_group_leader(p_group_id, auth.uid())
     and public.group_leader_count(p_group_id, auth.uid()) = 0 then
    raise exception 'transferencia_necessaria';
  end if;

  update public.group_members
  set status = 'left', updated_at = now()
  where group_id = p_group_id and user_id = auth.uid() and status = 'active';

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = auth.uid();

  select mr.user_id into v_new_owner
  from public.group_member_roles mr
  join public.group_roles r on r.id = mr.role_id
  join public.group_members m
    on m.group_id = mr.group_id and m.user_id = mr.user_id and m.status = 'active'
  where mr.group_id = p_group_id and r.is_system
  order by mr.assigned_at
  limit 1;

  if v_new_owner is not null then
    update public.groups
    set owner_id = v_new_owner, updated_by = auth.uid(), updated_at = now()
    where id = p_group_id and owner_id = auth.uid();

    update public.conversations
    set owner_id = v_new_owner
    where group_id = p_group_id and owner_id = auth.uid();
  end if;

  perform public.group_audit(p_group_id, 'leave_group', 'group_members', auth.uid());
end;
$$;
grant execute on function public.leave_group(uuid) to authenticated;

create or replace function public.remove_group_member(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_owner uuid;
begin
  if not public.has_group_permission(p_group_id, 'manage_members', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if p_user_id = auth.uid() then raise exception 'nao_pode_se_remover'; end if;
  if public.is_group_leader(p_group_id, p_user_id)
     and public.group_leader_count(p_group_id, p_user_id) = 0 then
    raise exception 'transferencia_necessaria';
  end if;

  update public.group_members
  set status = 'removed', updated_at = now()
  where group_id = p_group_id and user_id = p_user_id and status = 'active';

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = p_user_id;

  select mr.user_id into v_new_owner
  from public.group_member_roles mr
  join public.group_roles r on r.id = mr.role_id
  join public.group_members m
    on m.group_id = mr.group_id and m.user_id = mr.user_id and m.status = 'active'
  where mr.group_id = p_group_id and r.is_system
  order by mr.assigned_at
  limit 1;

  if v_new_owner is not null then
    update public.groups
    set owner_id = v_new_owner, updated_by = auth.uid(), updated_at = now()
    where id = p_group_id and owner_id = p_user_id;

    update public.conversations
    set owner_id = v_new_owner
    where group_id = p_group_id and owner_id = p_user_id;
  end if;

  perform public.group_audit(p_group_id, 'remove_member', 'group_members', p_user_id);
end;
$$;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

-- Backfill: garante um cargo de gestao por grupo e o dono atual como portador.
create unique index if not exists group_roles_one_system
  on public.group_roles (group_id) where is_system;

update public.group_roles r
set name = public.group_leader_role_name(g.category),
    permissions = array[
      'manage_group','manage_roles','manage_members','manage_invites',
      'post_as_group','moderate_content'
    ]::text[],
    updated_at = now()
from public.groups g
where r.group_id = g.id and r.is_system;

insert into public.group_member_roles (group_id, user_id, role_id, assigned_by)
select g.id, g.owner_id, r.id, g.owner_id
from public.groups g
join public.group_roles r on r.group_id = g.id and r.is_system
join public.group_members m
  on m.group_id = g.id and m.user_id = g.owner_id and m.status = 'active'
where not exists (
  select 1 from public.group_member_roles mr
  where mr.group_id = g.id and mr.user_id = g.owner_id and mr.role_id = r.id
);

-- Remove referencias antigas que davam privilegio ao owner fora do cargo.
create or replace function public.delete_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.groups where id = p_group_id;
  if v_owner is null then raise exception 'grupo_inexistente'; end if;
  if v_owner <> auth.uid() and not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (auth.uid(), 'delete_group', v_owner, jsonb_build_object('group_id', p_group_id));

  delete from public.groups where id = p_group_id;
end;
$$;
grant execute on function public.delete_group(uuid) to authenticated;
