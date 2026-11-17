-- P4 fix: garantir que o dono do grupo entre no chat mesmo sem linha ativa
-- em group_members.

create or replace function public.get_or_create_group_chat(p_group_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups%rowtype;
  v_conv uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select * into v_group from public.groups where id = p_group_id;
  if v_group.id is null or not public.can_view_group(p_group_id) then
    raise exception 'grupo_indisponivel';
  end if;
  if not public.is_group_member(p_group_id, auth.uid()) then
    raise exception 'apenas_membros';
  end if;

  select id into v_conv from public.conversations where group_id = p_group_id;
  if v_conv is null then
    insert into public.conversations (
      kind, title, owner_id, status, initiator_id, group_id
    ) values (
      'group_chat', v_group.name, v_group.owner_id, 'accepted', auth.uid(), p_group_id
    ) returning id into v_conv;
  end if;

  insert into public.conversation_participants (conversation_id, user_id, role)
  select
    v_conv,
    gm.user_id,
    case when gm.user_id = v_group.owner_id then 'owner' else 'member' end
  from public.group_members gm
  where gm.group_id = p_group_id and gm.status = 'active'
  on conflict (conversation_id, user_id) do nothing;

  insert into public.conversation_participants (conversation_id, user_id, role)
  values (v_conv, v_group.owner_id, 'owner')
  on conflict (conversation_id, user_id) do nothing;

  return v_conv;
end;
$$;
grant execute on function public.get_or_create_group_chat(uuid)
  to authenticated;
