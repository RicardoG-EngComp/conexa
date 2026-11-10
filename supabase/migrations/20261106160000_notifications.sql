-- Notificacoes: tokens, preferencias, fila, gatilhos e diagnostico admin
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own" on public.device_tokens
  for select to authenticated
  using (user_id = auth.uid());

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  message_requests boolean not null default true,
  messages boolean not null default true,
  connections boolean not null default true,
  studies boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists "notification_preferences_select_own" on public.notification_preferences;
create policy "notification_preferences_select_own" on public.notification_preferences
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "notification_preferences_insert_own" on public.notification_preferences;
create policy "notification_preferences_insert_own" on public.notification_preferences
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "notification_preferences_update_own" on public.notification_preferences;
create policy "notification_preferences_update_own" on public.notification_preferences
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in (
    'message_request',
    'message',
    'connection_request',
    'connection_accepted',
    'study_pending',
    'study_approved',
    'study_rejected'
  )),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  pushed_at timestamptz,
  push_attempts integer not null default 0,
  push_error text,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_pending_idx
  on public.notifications (pushed_at, push_attempts, created_at);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select to authenticated
  using (user_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then
  null;
end;
$$;

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
        else false
      end
      from public.notification_preferences p
      where p.user_id = p_user_id
    ),
    true
  );
$$;

revoke all on function public.notification_type_enabled(uuid, text) from anon, authenticated;

create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then return; end if;
  if auth.uid() is not null and p_user_id = auth.uid() then return; end if;
  if not public.notification_type_enabled(p_user_id, p_type) then return; end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;

revoke all on function public.enqueue_notification(uuid, text, text, text, jsonb) from anon, authenticated;

create or replace function public.notify_conversation_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_initiator uuid;
begin
  select status, initiator_id into v_status, v_initiator
  from public.conversations
  where id = new.conversation_id;

  if v_status = 'pending' and v_initiator is not null and new.user_id <> v_initiator then
    perform public.enqueue_notification(
      new.user_id,
      'message_request',
      'Novo pedido de mensagem',
      'Voce recebeu um pedido de mensagem.',
      jsonb_build_object(
        'route', '/chats?tab=requests',
        'conversation_id', new.conversation_id
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_conversation_request on public.conversation_participants;
create trigger trg_notify_conversation_request
after insert on public.conversation_participants
for each row execute function public.notify_conversation_request();

create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_other uuid;
begin
  select status into v_status
  from public.conversations
  where id = new.conversation_id;

  if v_status <> 'accepted' then return new; end if;

  select cp.user_id into v_other
  from public.conversation_participants cp
  where cp.conversation_id = new.conversation_id
    and cp.user_id <> new.sender_id
  limit 1;

  if v_other is not null and not public.is_blocked(v_other, new.sender_id) then
    perform public.enqueue_notification(
      v_other,
      'message',
      'Nova mensagem',
      'Nova mensagem',
      jsonb_build_object(
        'route', '/chats/' || new.conversation_id::text,
        'conversation_id', new.conversation_id
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_new_message on public.messages;
create trigger trg_notify_new_message
after insert on public.messages
for each row execute function public.notify_new_message();

create or replace function public.notify_connection_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending' then
    perform public.enqueue_notification(
      new.addressee_id,
      'connection_request',
      'Nova solicitacao de conexao',
      'Voce recebeu uma solicitacao de conexao.',
      jsonb_build_object(
        'route', '/chats?tab=connections',
        'requester_id', new.requester_id
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_connection_insert on public.connections;
create trigger trg_notify_connection_insert
after insert on public.connections
for each row execute function public.notify_connection_insert();

create or replace function public.notify_connection_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status and new.status = 'accepted' then
    perform public.enqueue_notification(
      new.requester_id,
      'connection_accepted',
      'Conexao aceita',
      'Sua solicitacao de conexao foi aceita.',
      jsonb_build_object(
        'route', '/chats?tab=connections',
        'addressee_id', new.addressee_id
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_connection_update on public.connections;
create trigger trg_notify_connection_update
after update on public.connections
for each row execute function public.notify_connection_update();

create or replace function public.notify_study_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  if new.status = 'pending' then
    for v_admin in select user_id from public.admins loop
      if v_admin.user_id <> new.author_id then
        perform public.enqueue_notification(
          v_admin.user_id,
          'study_pending',
          'Novo material pendente',
          'Ha um material aguardando aprovacao.',
          jsonb_build_object(
            'route', '/admin/studies',
            'material_id', new.id,
            'discipline_id', new.discipline_id
          )
        );
      end if;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_study_insert on public.study_materials;
create trigger trg_notify_study_insert
after insert on public.study_materials
for each row execute function public.notify_study_insert();

create or replace function public.notify_study_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status is distinct from new.status
     and new.status in ('approved', 'rejected') then
    perform public.enqueue_notification(
      new.author_id,
      case when new.status = 'approved' then 'study_approved' else 'study_rejected' end,
      case when new.status = 'approved' then 'Material aprovado' else 'Material rejeitado' end,
      case
        when new.status = 'approved' then 'Seu material foi aprovado.'
        else 'Seu material foi rejeitado.'
      end,
      jsonb_build_object(
        'route', '/studies/material/' || new.id::text,
        'material_id', new.id,
        'discipline_id', new.discipline_id,
        'status', new.status
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_study_status on public.study_materials;
create trigger trg_notify_study_status
after update on public.study_materials
for each row execute function public.notify_study_status();

create or replace function public.register_device_token(
  p_token text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_token is null or length(btrim(p_token)) < 20 then
    raise exception 'invalid token';
  end if;

  insert into public.device_tokens (user_id, token, platform, last_seen_at, updated_at)
  values (
    auth.uid(),
    btrim(p_token),
    coalesce(nullif(btrim(p_platform), ''), 'android'),
    now(),
    now()
  )
  on conflict (token) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      last_seen_at = now(),
      updated_at = now();
end;
$$;

grant execute on function public.register_device_token(text, text) to authenticated;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.device_tokens
  where token = btrim(p_token) and user_id = auth.uid();
end;
$$;

grant execute on function public.unregister_device_token(text) to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.notifications
  set read_at = now()
  where id = p_notification_id
    and user_id = auth.uid()
    and read_at is null;
end;
$$;

grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.notifications
  set read_at = now()
  where user_id = auth.uid() and read_at is null;
end;
$$;

grant execute on function public.mark_all_notifications_read() to authenticated;

create or replace function public.admin_notification_diagnostics(
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_errors jsonb;
  v_tokens jsonb;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', n.id,
    'type', n.type,
    'attempts', n.push_attempts,
    'error', n.push_error,
    'created_at', n.created_at
  ) order by n.created_at desc), '[]'::jsonb)
  into v_errors
  from (
    select id, type, push_attempts, push_error, created_at
    from public.notifications
    where pushed_at is null and push_error is not null
    order by created_at desc
    limit greatest(p_limit, 1)
  ) n;

  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', t.user_id,
    'platform', t.platform,
    'last_seen_at', t.last_seen_at,
    'token_masked', right(t.token, 6)
  ) order by t.last_seen_at desc), '[]'::jsonb)
  into v_tokens
  from (
    select user_id, platform, last_seen_at, token
    from public.device_tokens
    order by last_seen_at desc
    limit greatest(p_limit, 1)
  ) t;

  return jsonb_build_object(
    'pending', (select count(*) from public.notifications where pushed_at is null),
    'sent', (select count(*) from public.notifications where pushed_at is not null),
    'failed', (select count(*) from public.notifications where pushed_at is null and push_error is not null),
    'tokens', (select count(*) from public.device_tokens),
    'recent_errors', v_errors,
    'recent_tokens', v_tokens
  );
end;
$$;

grant execute on function public.admin_notification_diagnostics(integer) to authenticated;
