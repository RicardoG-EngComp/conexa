-- P2: chat social (grupos, reply, reacoes, edicao, midia, pin/mute/archive,
-- digitando). Sem E2EE no MVP.

-- @@

-- 1) Conversas e participantes.

alter table public.conversations
  add column if not exists kind text not null default 'direct',
  add column if not exists title text,
  add column if not exists owner_id uuid references auth.users(id) on delete set null,
  add column if not exists updated_at timestamptz not null default now();

alter table public.conversations
  drop constraint if exists conversations_kind_check;
alter table public.conversations
  add constraint conversations_kind_check
  check (kind in ('direct', 'group'));

alter table public.conversations
  drop constraint if exists conversations_title_check;
alter table public.conversations
  add constraint conversations_title_check
  check (
    (kind = 'direct' and title is null)
    or (kind = 'group' and char_length(btrim(title)) between 3 and 80)
  );

alter table public.conversation_participants
  add column if not exists role text not null default 'member',
  add column if not exists joined_at timestamptz not null default now(),
  add column if not exists pinned_at timestamptz,
  add column if not exists muted_until timestamptz,
  add column if not exists archived_at timestamptz;

alter table public.conversation_participants
  drop constraint if exists participants_role_check;
alter table public.conversation_participants
  add constraint participants_role_check
  check (role in ('owner', 'member'));

create index if not exists conversations_kind_idx
  on public.conversations (kind);

create or replace function public.guard_participant_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or public.is_admin_user(auth.uid()) then
    return new;
  end if;

  if new.conversation_id <> old.conversation_id
     or new.user_id <> old.user_id then
    raise exception 'campo_de_participante_protegido';
  end if;

  new.role := old.role;
  new.joined_at := old.joined_at;
  return new;
end;
$$;

drop trigger if exists participants_guard_fields
  on public.conversation_participants;
create trigger participants_guard_fields
before update on public.conversation_participants
for each row execute function public.guard_participant_fields();

-- @@

-- 2) Mensagens: reply, edicao e midia.

alter table public.messages
  add column if not exists reply_to_id uuid references public.messages(id) on delete set null,
  add column if not exists edited_at timestamptz,
  add column if not exists media_path text,
  add column if not exists media_mime text,
  add column if not exists media_bytes bigint,
  add column if not exists media_width integer,
  add column if not exists media_height integer,
  add column if not exists media_duration_ms integer,
  add column if not exists media_name text;

create index if not exists messages_reply_idx on public.messages (reply_to_id);
create index if not exists messages_media_idx on public.messages (media_path)
  where media_path is not null;

alter table public.messages drop constraint if exists messages_kind_check;
alter table public.messages add constraint messages_kind_check
  check (kind in ('text', 'sticker', 'gif', 'image', 'video', 'file'));

alter table public.messages drop constraint if exists messages_content_check;
alter table public.messages add constraint messages_content_check check (
  (kind = 'text' and char_length(content) between 1 and 2000)
  or (kind = 'sticker' and sticker_path is not null)
  or (kind = 'gif' and gif_url is not null)
  or (
    kind in ('image', 'video', 'file')
    and media_path is not null
    and char_length(content) between 0 and 2000
  )
);

create or replace function public.validate_message_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent public.messages%rowtype;
begin
  if new.reply_to_id is null then return new; end if;

  select * into v_parent from public.messages where id = new.reply_to_id;
  if v_parent.id is null then raise exception 'mensagem_pai_inexistente'; end if;
  if v_parent.conversation_id <> new.conversation_id then
    raise exception 'mensagem_de_outra_conversa';
  end if;
  if v_parent.deleted_for_all_at is not null then
    raise exception 'mensagem_apagada';
  end if;

  return new;
end;
$$;

drop trigger if exists messages_validate_reply on public.messages;
create trigger messages_validate_reply
before insert on public.messages
for each row execute function public.validate_message_reply();

create or replace function public.validate_message_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.media_path is null then return new; end if;

  if new.kind not in ('image', 'video', 'file') then
    raise exception 'midia_em_mensagem_invalida';
  end if;
  if new.media_mime is null or new.media_bytes is null or new.media_bytes <= 0 then
    raise exception 'midia_invalida';
  end if;
  if not exists (
    select 1 from public.media_objects mo
    where mo.owner_id = new.sender_id
      and mo.scope = 'chat'
      and mo.object_key = new.media_path
      and mo.deleted_at is null
      and (
        (new.kind = 'image' and mo.kind = 'chat_image')
        or (new.kind = 'video' and mo.kind = 'chat_video')
        or (new.kind = 'file' and mo.kind = 'chat_file')
      )
  ) then
    raise exception 'midia_invalida';
  end if;

  return new;
end;
$$;

drop trigger if exists messages_validate_media on public.messages;
create trigger messages_validate_media
before insert on public.messages
for each row execute function public.validate_message_media();

create or replace function public.touch_conversation_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set updated_at = now()
  where id = new.conversation_id;
  delete from public.typing_indicators
  where conversation_id = new.conversation_id and user_id = new.sender_id;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
after insert on public.messages
for each row execute function public.touch_conversation_on_message();

drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
    and not public.conversation_has_block(conversation_id)
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
  );

-- @@

-- 3) Reacoes e digitando.

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 8),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists message_reactions_conversation_idx
  on public.message_reactions (conversation_id);

alter table public.message_reactions enable row level security;

drop policy if exists "message_reactions_select_participant"
  on public.message_reactions;
create policy "message_reactions_select_participant"
  on public.message_reactions
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
  );

create or replace function public.set_reaction_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select conversation_id into new.conversation_id
  from public.messages where id = new.message_id;
  if new.conversation_id is null then raise exception 'mensagem_inexistente'; end if;
  return new;
end;
$$;

drop trigger if exists message_reactions_set_conversation
  on public.message_reactions;
create trigger message_reactions_set_conversation
before insert on public.message_reactions
for each row execute function public.set_reaction_conversation();

create table if not exists public.typing_indicators (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.typing_indicators enable row level security;

drop policy if exists "typing_select_participant" on public.typing_indicators;
create policy "typing_select_participant" on public.typing_indicators
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
  );

drop policy if exists "typing_insert_own" on public.typing_indicators;
create policy "typing_insert_own" on public.typing_indicators
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
    and public.is_active_user(auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
  );

drop policy if exists "typing_update_own" on public.typing_indicators;
create policy "typing_update_own" on public.typing_indicators
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and public.is_conversation_participant(conversation_id)
  );

drop policy if exists "typing_delete_own" on public.typing_indicators;
create policy "typing_delete_own" on public.typing_indicators
  for delete to authenticated using (user_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.message_reactions;
exception when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.typing_indicators;
exception when duplicate_object then null;
end;
$$;

-- @@

-- 4) RPCs de conversa.

create or replace function public.create_group_conversation(
  p_title text,
  p_member_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv uuid := gen_random_uuid();
  v_title text := btrim(coalesce(p_title, ''));
  v_member uuid;
  v_count int := 0;
  v_recent int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then
    raise exception 'diretrizes_necessarias';
  end if;
  if char_length(v_title) < 3 or char_length(v_title) > 80 then
    raise exception 'titulo_invalido';
  end if;
  if p_member_ids is null or array_length(p_member_ids, 1) < 1
     or array_length(p_member_ids, 1) > 20 then
    raise exception 'membros_invalidos';
  end if;

  select count(*) into v_recent
  from public.conversations
  where kind = 'group' and owner_id = auth.uid()
    and created_at > now() - interval '24 hours';
  if v_recent >= 10 then raise exception 'limite_grupos'; end if;

  insert into public.conversations (id, kind, title, owner_id, status, initiator_id)
  values (v_conv, 'group', v_title, auth.uid(), 'accepted', auth.uid());

  insert into public.conversation_participants (conversation_id, user_id, role)
  values (v_conv, auth.uid(), 'owner');

  for v_member in
    select distinct value from unnest(p_member_ids) as t(value) limit 20
  loop
    if v_member = auth.uid() then continue; end if;
    if not public.is_active_user(v_member) then continue; end if;
    if public.is_blocked(auth.uid(), v_member) then continue; end if;
    if not public.is_connection(auth.uid(), v_member) then continue; end if;
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (v_conv, v_member, 'member')
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  if v_count = 0 then
    delete from public.conversations where id = v_conv;
    raise exception 'sem_membros_validos';
  end if;

  return jsonb_build_object('conversation_id', v_conv, 'members', v_count + 1);
end;
$$;
grant execute on function public.create_group_conversation(text, uuid[])
  to authenticated;

create or replace function public.set_conversation_pinned(
  p_conversation_id uuid,
  p_pin boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversation_participants
  set pinned_at = case when p_pin then now() else null end
  where conversation_id = p_conversation_id and user_id = auth.uid();
  if not found then raise exception 'conversa_inacessivel'; end if;
  return jsonb_build_object('pinned', p_pin);
end;
$$;
grant execute on function public.set_conversation_pinned(uuid, boolean)
  to authenticated;

create or replace function public.set_conversation_muted(
  p_conversation_id uuid,
  p_muted boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversation_participants
  set muted_until = case when p_muted then now() + interval '100 years' else null end
  where conversation_id = p_conversation_id and user_id = auth.uid();
  if not found then raise exception 'conversa_inacessivel'; end if;
  return jsonb_build_object('muted', p_muted);
end;
$$;
grant execute on function public.set_conversation_muted(uuid, boolean)
  to authenticated;

create or replace function public.set_conversation_archived(
  p_conversation_id uuid,
  p_archived boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversation_participants
  set archived_at = case when p_archived then now() else null end
  where conversation_id = p_conversation_id and user_id = auth.uid();
  if not found then raise exception 'conversa_inacessivel'; end if;
  return jsonb_build_object('archived', p_archived);
end;
$$;
grant execute on function public.set_conversation_archived(uuid, boolean)
  to authenticated;

-- @@

-- 5) RPCs de mensagem.

create or replace function public.edit_message(
  p_message_id uuid,
  p_content text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message public.messages%rowtype;
  v_content text := btrim(coalesce(p_content, ''));
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception 'conteudo_invalido';
  end if;

  select * into v_message from public.messages where id = p_message_id;
  if v_message.id is null or v_message.sender_id <> auth.uid() then
    raise exception 'mensagem_inacessivel';
  end if;
  if v_message.kind <> 'text' or v_message.deleted_for_all_at is not null then
    raise exception 'mensagem_nao_editavel';
  end if;
  if v_message.created_at < now() - interval '15 minutes' then
    raise exception 'prazo_de_edicao_expirado';
  end if;

  update public.messages
  set content = v_content, edited_at = now()
  where id = p_message_id;

  return jsonb_build_object('edited_at', now());
end;
$$;
grant execute on function public.edit_message(uuid, text) to authenticated;

create or replace function public.toggle_message_reaction(
  p_message_id uuid,
  p_emoji text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message public.messages%rowtype;
  v_emoji text := btrim(coalesce(p_emoji, ''));
  v_existing text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if char_length(v_emoji) < 1 or char_length(v_emoji) > 8 then
    raise exception 'emoji_invalido';
  end if;

  select * into v_message from public.messages where id = p_message_id;
  if v_message.id is null
     or not public.is_conversation_participant(v_message.conversation_id)
     or v_message.deleted_for_all_at is not null then
    raise exception 'mensagem_inacessivel';
  end if;

  select emoji into v_existing
  from public.message_reactions
  where message_id = p_message_id and user_id = auth.uid();

  if v_existing = v_emoji then
    delete from public.message_reactions
    where message_id = p_message_id and user_id = auth.uid();
    return jsonb_build_object('reacted', false);
  end if;

  insert into public.message_reactions (message_id, conversation_id, user_id, emoji)
  values (p_message_id, v_message.conversation_id, auth.uid(), v_emoji)
  on conflict (message_id, user_id) do update
    set emoji = excluded.emoji,
        created_at = now();

  return jsonb_build_object('reacted', true);
end;
$$;
grant execute on function public.toggle_message_reaction(uuid, text)
  to authenticated;

create or replace function public.delete_message_for_everyone(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conv uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  update public.messages
  set deleted_for_all_at = now(),
      content = 'Mensagem apagada',
      kind = 'text',
      sticker_path = null,
      gif_url = null,
      media_path = null,
      media_mime = null,
      media_bytes = null,
      media_width = null,
      media_height = null,
      media_duration_ms = null,
      media_name = null,
      reply_to_id = null
  where id = p_message_id
    and sender_id = auth.uid()
    and deleted_for_all_at is null
    and created_at > now() - interval '5 minutes'
  returning conversation_id into v_conv;

  if v_conv is null then
    raise exception 'message can no longer be deleted for everyone';
  end if;

  delete from public.message_reactions where message_id = p_message_id;

  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.delete_message_for_everyone(uuid) to authenticated;

-- @@

-- 6) start_conversation e pedido continuam apenas 1:1.

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
  where c.kind = 'direct'
  limit 1;

  if conv_id is not null then
    update public.conversations set status = 'accepted' where id = conv_id;
    return conv_id;
  end if;

  insert into public.conversations (kind, status, initiator_id)
  values ('direct', 'accepted', auth.uid())
  returning id into conv_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values (conv_id, auth.uid()), (conv_id, other_user);
  return conv_id;
end;
$$;
grant execute on function public.start_conversation(uuid) to authenticated;

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
  where c.kind = 'direct'
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

  insert into public.conversations (kind, status, initiator_id, request_message)
  values ('direct', 'pending', auth.uid(), btrim(message))
  returning id into conv_id;

  insert into public.conversation_participants (conversation_id, user_id)
  values (conv_id, auth.uid()), (conv_id, other_user);

  return jsonb_build_object('id', conv_id, 'status', 'pending');
end;
$$;
grant execute on function public.send_message_request(uuid, text) to authenticated;

-- @@

-- 7) Notificacao de mensagem para grupos e respeitando mute.

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

-- @@

-- 8) Limpeza/exclusao tambem remove digitando.

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

  delete from public.typing_indicators
  where conversation_id = p_conversation_id and user_id = auth.uid();

  return jsonb_build_object('ok', true);
end;
$$;

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

  delete from public.typing_indicators
  where conversation_id = p_conversation_id and user_id = auth.uid();

  return jsonb_build_object('ok', true);
end;
$$;

-- @@

-- 9) Midia do chat.

alter table public.media_objects
  drop constraint if exists media_objects_scope_check;
alter table public.media_objects
  add constraint media_objects_scope_check
  check (scope in ('profile', 'study', 'feed', 'chat'));

alter table public.media_objects
  drop constraint if exists media_objects_kind_check;
alter table public.media_objects
  add constraint media_objects_kind_check
  check (
    kind in (
      'avatar', 'photo', 'study_pdf', 'study_image', 'feed_image', 'feed_video',
      'chat_image', 'chat_video', 'chat_file'
    )
  );

create or replace function public.filter_visible_chat_media(paths text[])
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(array_agg(distinct m.media_path), '{}'::text[])
  from public.messages m
  where m.media_path = any(paths)
    and m.deleted_for_all_at is null
    and public.is_active_user(auth.uid())
    and public.is_conversation_participant(m.conversation_id)
    and not public.conversation_has_block(m.conversation_id)
    and exists (
      select 1 from public.conversations c
      where c.id = m.conversation_id and c.status = 'accepted'
    )
    and not exists (
      select 1 from public.message_deletions d
      where d.message_id = m.id and d.user_id = auth.uid()
    );
$$;
grant execute on function public.filter_visible_chat_media(text[])
  to authenticated;
