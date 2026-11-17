-- P5: gerenciar membros de conversa em grupo e mensagens de sistema.

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'sticker', 'gif', 'image', 'video', 'file', 'system'));

alter table public.messages drop constraint if exists messages_content_check;
alter table public.messages add constraint messages_content_check check (
  (kind = 'text' and char_length(content) between 1 and 2000)
  or (kind = 'system' and char_length(content) between 1 and 2000)
  or (kind = 'sticker' and sticker_path is not null)
  or (kind = 'gif' and gif_url is not null)
  or (
    kind in ('image', 'video', 'file')
    and media_path is not null
    and char_length(content) between 0 and 2000
  )
);

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_target uuid;
begin
  if new.kind = 'system' then return new; end if;

  select status into v_status
  from public.conversations where id = new.conversation_id;
  if v_status <> 'accepted' then return new; end if;

  for v_target in
    select cp.user_id
    from public.conversation_participants cp
    where cp.conversation_id = new.conversation_id
      and cp.user_id <> new.sender_id
      and (cp.muted_until is null or cp.muted_until <= now())
  loop
    if public.is_active_user(v_target)
       and not public.is_blocked(v_target, new.sender_id) then
      perform public.enqueue_notification(
        v_target,
        'message',
        'Nova mensagem',
        'Nova mensagem',
        jsonb_build_object(
          'route', '/chats/' || new.conversation_id::text,
          'conversation_id', new.conversation_id
        )
      );
    end if;
  end loop;

  return new;
end;
$$;

create or replace function public.add_conversation_members(
  p_conversation_id uuid,
  p_user_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind text;
  v_owner uuid;
  v_user uuid;
  v_added int := 0;
  v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select kind, owner_id into v_kind, v_owner
  from public.conversations where id = p_conversation_id;
  if v_kind is distinct from 'group' then raise exception 'grupo_necessario'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_user_ids is null or array_length(p_user_ids, 1) > 50 then
    raise exception 'membros_invalidos';
  end if;

  select count(*) into v_count
  from public.conversation_participants where conversation_id = p_conversation_id;

  for v_user in select distinct value from unnest(p_user_ids) as t(value)
  loop
    if v_user = auth.uid() then continue; end if;
    if v_count + v_added >= 50 then raise exception 'limite_membros'; end if;
    if not public.is_active_user(v_user) then continue; end if;
    if public.is_blocked(auth.uid(), v_user) then continue; end if;
    if not public.is_connection(auth.uid(), v_user) then continue; end if;
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (p_conversation_id, v_user, 'member')
    on conflict (conversation_id, user_id) do nothing;
    if found then
      v_added := v_added + 1;
      insert into public.messages (conversation_id, sender_id, content, kind)
      values (p_conversation_id, auth.uid(), 'Um novo membro entrou no grupo.', 'system');
    end if;
  end loop;

  return jsonb_build_object('added', v_added);
end;
$$;
grant execute on function public.add_conversation_members(uuid, uuid[])
  to authenticated;

create or replace function public.remove_conversation_member(
  p_conversation_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind text;
  v_owner uuid;
  v_role text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select kind, owner_id into v_kind, v_owner
  from public.conversations where id = p_conversation_id;
  if v_kind is distinct from 'group' then raise exception 'grupo_necessario'; end if;
  if v_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if p_user_id = v_owner then raise exception 'dono_nao_pode_sair'; end if;

  select role into v_role
  from public.conversation_participants
  where conversation_id = p_conversation_id and user_id = p_user_id;
  if v_role is null then raise exception 'membro_inexistente'; end if;

  delete from public.conversation_participants
  where conversation_id = p_conversation_id and user_id = p_user_id;

  insert into public.messages (conversation_id, sender_id, content, kind)
  values (p_conversation_id, auth.uid(), 'Um membro saiu do grupo.', 'system');

  return jsonb_build_object('removed', true);
end;
$$;
grant execute on function public.remove_conversation_member(uuid, uuid)
  to authenticated;
