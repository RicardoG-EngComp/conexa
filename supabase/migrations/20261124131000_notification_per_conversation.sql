-- Uma unica notificacao nao lida por conversa, com contagem total de mensagens.

alter table public.notifications
  add column if not exists conversation_id uuid
  references public.conversations(id) on delete cascade;

update public.notifications n
set conversation_id = (n.data ->> 'conversation_id')::uuid
where n.conversation_id is null
  and n.type = 'message'
  and (n.data ->> 'conversation_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.conversations c
    where c.id = (n.data ->> 'conversation_id')::uuid
  );

with ranked as (
  select id,
         row_number() over (
           partition by user_id, conversation_id
           order by created_at desc, id desc
         ) as rn
  from public.notifications
  where type = 'message'
    and read_at is null
    and conversation_id is not null
)
delete from public.notifications n
using ranked r
where n.id = r.id and r.rn > 1;

create unique index if not exists notifications_message_conversation_unread_uidx
  on public.notifications (user_id, conversation_id)
  where type = 'message' and read_at is null and conversation_id is not null;

create or replace function public.enqueue_message_notification(
  p_user_id uuid,
  p_conversation_id uuid,
  p_title text,
  p_body text,
  p_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.notification_type_enabled(p_user_id, 'message') then return; end if;

  insert into public.notifications
    (user_id, type, title, body, data, conversation_id)
  values (
    p_user_id, 'message', p_title, p_body, coalesce(p_data, '{}'::jsonb),
    p_conversation_id
  )
  on conflict (user_id, conversation_id)
    where type = 'message' and read_at is null and conversation_id is not null and conversation_id is not null
  do update set
    title = excluded.title,
    body = excluded.body,
    data = excluded.data,
    created_at = now(),
    pushed_at = null,
    push_attempts = 0,
    push_error = null;
end;
$$;
revoke all on function public.enqueue_message_notification(uuid, uuid, text, text, jsonb)
  from public;

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_kind text;
  v_conversation_title text;
  v_sender_name text;
  v_target uuid;
  v_last_read timestamptz;
  v_unread integer;
  v_title text;
  v_body text;
begin
  if new.kind = 'system' then return new; end if;

  select c.status, c.kind, c.title
  into v_status, v_kind, v_conversation_title
  from public.conversations c
  where c.id = new.conversation_id;
  if v_status is distinct from 'accepted' then return new; end if;

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
        and m.sender_id <> v_target
        and m.kind <> 'system'
        and m.deleted_for_all_at is null
        and (v_last_read is null or m.created_at > v_last_read);

      if v_kind in ('group', 'group_chat') then
        v_title := coalesce(nullif(btrim(v_conversation_title), ''), v_sender_name);
      else
        v_title := v_sender_name;
      end if;

      v_body := case
        when v_unread > 1 then v_unread || ' novas mensagens'
        else 'Nova mensagem'
      end;

      perform public.enqueue_message_notification(
        v_target,
        new.conversation_id,
        v_title,
        v_body,
        jsonb_build_object(
          'route', '/chats/' || new.conversation_id::text,
          'conversation_id', new.conversation_id,
          'sender_id', new.sender_id,
          'sender_name', v_sender_name,
          'unread_count', v_unread,
          'group_title', case
            when v_kind in ('group', 'group_chat') then v_conversation_title
          end
        )
      );
    end if;
  end loop;

  return new;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  update public.conversation_participants
  set last_read_at = now()
  where conversation_id = p_conversation_id and user_id = auth.uid();

  update public.notifications
  set read_at = now()
  where user_id = auth.uid()
    and type = 'message'
    and conversation_id = p_conversation_id
    and read_at is null;
end;
$$;
grant execute on function public.mark_conversation_read(uuid)
  to authenticated;
