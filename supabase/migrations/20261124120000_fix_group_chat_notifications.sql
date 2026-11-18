-- Correcoes pos-P5: campus padrao, nome do grupo no chat e push por remetente.

update public.groups
set campus = 'Viçosa'
where campus in ('ViÃ§osa', 'ViÃƒÂ§osa');

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
grant execute on function public.create_group(text, text, text, text, text, text)
  to authenticated;

-- Push de mensagem: nome publico do remetente + contagem nao lida por remetente.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_kind text;
  v_group_title text;
  v_sender_name text;
  v_target uuid;
  v_last_read timestamptz;
  v_unread integer;
begin
  select c.status, c.kind, c.title
  into v_status, v_kind, v_group_title
  from public.conversations c
  where c.id = new.conversation_id;
  if v_status <> 'accepted' then return new; end if;

  select coalesce(nullif(btrim(p.display_name), ''), 'Estudante UFV')
  into v_sender_name
  from public.profiles_public p
  where p.id = new.sender_id;
  v_sender_name := coalesce(v_sender_name, 'Estudante UFV');

  for v_target in
    select cp.user_id
    from public.conversation_participants cp
    where cp.conversation_id = new.conversation_id
      and cp.user_id <> new.sender_id
      and (cp.muted_until is null or cp.muted_until <= now())
  loop
    if public.is_active_user(v_target)
       and not public.is_blocked(v_target, new.sender_id) then
      select cp.last_read_at
      into v_last_read
      from public.conversation_participants cp
      where cp.conversation_id = new.conversation_id
        and cp.user_id = v_target;

      select count(*)
      into v_unread
      from public.messages m
      where m.conversation_id = new.conversation_id
        and m.sender_id = new.sender_id
        and m.deleted_for_all_at is null
        and (v_last_read is null or m.created_at > v_last_read);

      perform public.enqueue_notification(
        v_target,
        'message',
        v_sender_name,
        case
          when v_kind = 'group_chat' and v_group_title is not null then
            case
              when v_unread > 1 then v_unread || ' novas mensagens em ' || v_group_title
              else 'Nova mensagem em ' || v_group_title
            end
          else
            case
              when v_unread > 1 then v_unread || ' novas mensagens'
              else 'Nova mensagem'
            end
        end,
        jsonb_build_object(
          'route', '/chats/' || new.conversation_id::text,
          'conversation_id', new.conversation_id,
          'sender_id', new.sender_id,
          'sender_name', v_sender_name,
          'unread_count', v_unread,
          'group_title', case when v_kind = 'group_chat' then v_group_title end
        )
      );
    end if;
  end loop;

  return new;
end;
$$;
