-- Gestao de conversas e mensagens
alter table public.conversation_participants
  add column if not exists cleared_at timestamptz,
  add column if not exists hidden_at timestamptz;

alter table public.messages
  add column if not exists deleted_for_all_at timestamptz;

create table if not exists public.message_deletions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.message_deletions enable row level security;

drop policy if exists "message_deletions_select_own" on public.message_deletions;
create policy "message_deletions_select_own" on public.message_deletions
  for select to authenticated
  using (user_id = auth.uid());

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

create or replace function public.clear_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  update public.conversation_participants
  set cleared_at = now(), last_read_at = now()
  where conversation_id = p_conversation_id and user_id = auth.uid();

  if not found then raise exception 'conversation not found'; end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.clear_conversation(uuid) to authenticated;

create or replace function public.delete_conversation(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  update public.conversation_participants
  set hidden_at = now(), cleared_at = now(), last_read_at = now()
  where conversation_id = p_conversation_id and user_id = auth.uid();

  if not found then raise exception 'conversation not found'; end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.delete_conversation(uuid) to authenticated;

create or replace function public.delete_message_for_me(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select conversation_id into conv_id
  from public.messages
  where id = p_message_id;

  if conv_id is null then raise exception 'message not found'; end if;
  if not public.is_conversation_participant(conv_id) then
    raise exception 'not allowed';
  end if;

  insert into public.message_deletions (message_id, user_id)
  values (p_message_id, auth.uid())
  on conflict do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.delete_message_for_me(uuid) to authenticated;

create or replace function public.delete_message_for_everyone(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  update public.messages
  set deleted_for_all_at = now(),
      content = 'Mensagem apagada',
      kind = 'text',
      sticker_path = null,
      gif_url = null
  where id = p_message_id
    and sender_id = auth.uid()
    and deleted_for_all_at is null
    and created_at > now() - interval '5 minutes';

  if not found then
    raise exception 'message can no longer be deleted for everyone';
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.delete_message_for_everyone(uuid) to authenticated;

create or replace function public.cancel_connection_request(p_target_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  delete from public.connections
  where requester_id = auth.uid()
    and addressee_id = p_target_user
    and status = 'pending';

  if not found then raise exception 'request not found'; end if;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.cancel_connection_request(uuid) to authenticated;
