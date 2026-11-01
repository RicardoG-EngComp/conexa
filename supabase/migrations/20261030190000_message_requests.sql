-- Fase 1: pedidos de mensagem + perfil privado
alter table public.conversations
  add column if not exists status text not null default 'accepted'
    check (status in ('pending', 'accepted', 'declined')),
  add column if not exists initiator_id uuid references auth.users(id),
  add column if not exists request_message text,
  add column if not exists declined_at timestamptz;

alter table public.profiles
  add column if not exists profile_private boolean not null default false;

-- Mensagens somente em conversas aceitas
drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
  );

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
  );

-- Destinatario pode aceitar/recusar
drop policy if exists "conversations_update_recipient" on public.conversations;
create policy "conversations_update_recipient" on public.conversations
  for update to authenticated
  using (
    public.is_conversation_participant(id)
    and initiator_id is distinct from auth.uid()
  )
  with check (public.is_conversation_participant(id));

-- RPC de pedido de mensagem
create or replace function public.send_message_request(other_user uuid, message text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  conv record;
  conv_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if other_user = auth.uid() then raise exception 'cannot message yourself'; end if;
  if message is null or length(btrim(message)) = 0 then raise exception 'message required'; end if;
  if length(message) > 150 then raise exception 'message too long'; end if;

  select c.id, c.status, c.declined_at into conv
  from public.conversations c
  join public.conversation_participants p1
    on p1.conversation_id = c.id and p1.user_id = auth.uid()
  join public.conversation_participants p2
    on p2.conversation_id = c.id and p2.user_id = other_user
  order by c.created_at desc
  limit 1;

  if conv.id is not null then
    if conv.status = 'declined'
       and conv.declined_at > now() - interval '30 days' then
      raise exception 'request blocked for 30 days';
    end if;
    if conv.status in ('pending', 'accepted') then
      return jsonb_build_object('id', conv.id, 'status', conv.status);
    end if;
  end if;

  insert into public.conversations (status, initiator_id, request_message)
  values ('pending', auth.uid(), btrim(message))
  returning id into conv_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values (conv_id, auth.uid()), (conv_id, other_user);

  return jsonb_build_object('id', conv_id, 'status', 'pending');
end;
$$;

grant execute on function public.send_message_request(uuid, text) to authenticated;

-- View publica com flag de privacidade
drop view if exists public.profiles_public;
create view public.profiles_public as
  select id, display_name, course, campus, bio, prompts, avatar_url, photos,
         interests, relationship_style, verification_status, profile_private,
         created_at
  from public.profiles;

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;
