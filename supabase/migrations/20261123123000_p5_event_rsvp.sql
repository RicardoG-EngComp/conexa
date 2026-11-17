-- P5: RSVP e lembretes de eventos de grupo.

create table if not exists public.group_event_rsvps (
  event_id uuid not null references public.group_events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('going', 'interested', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.group_event_rsvps enable row level security;

drop policy if exists "group_event_rsvps_select_visible"
  on public.group_event_rsvps;
create policy "group_event_rsvps_select_visible"
  on public.group_event_rsvps
  for select to authenticated
  using (
    exists (
      select 1 from public.group_events e
      where e.id = event_id and public.can_view_group(e.group_id)
    )
  );

alter table public.group_events
  add column if not exists reminder_sent_at timestamptz;

create or replace function public.set_event_rsvp(
  p_event_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if p_status not in ('going', 'interested', 'declined') then
    raise exception 'status_invalido';
  end if;

  select group_id into v_group from public.group_events where id = p_event_id;
  if v_group is null or not public.can_view_group(v_group) then
    raise exception 'evento_inacessivel';
  end if;

  insert into public.group_event_rsvps (event_id, user_id, status)
  values (p_event_id, auth.uid(), p_status)
  on conflict (event_id, user_id) do update
    set status = excluded.status, updated_at = now();

  return jsonb_build_object('status', p_status);
end;
$$;
grant execute on function public.set_event_rsvp(uuid, text) to authenticated;

alter table public.notifications
  drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'message_request',
    'message',
    'connection_request',
    'connection_accepted',
    'study_pending',
    'study_approved',
    'study_rejected',
    'group_invite',
    'security_alert',
    'like',
    'comment',
    'mention',
    'repost',
    'event_reminder'
  ));

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
        when p_type in ('group_invite', 'event_reminder') then p.groups
        when p_type = 'security_alert' then p.security_alerts
        when p_type in ('like', 'comment', 'mention', 'repost') then p.interactions
        else false
      end
      from public.notification_preferences p
      where p.user_id = p_user_id
    ),
    true
  );
$$;

revoke all on function public.notification_type_enabled(uuid, text)
  from public, anon, authenticated;

create or replace function public.enqueue_event_reminders()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event record;
  v_target uuid;
  v_count int := 0;
begin
  for v_event in
    select e.id, e.group_id, e.title, e.starts_at
    from public.group_events e
    where e.reminder_sent_at is null
      and e.starts_at > now()
      and e.starts_at <= now() + interval '24 hours'
      and e.ends_at >= now()
  loop
    for v_target in
      select r.user_id
      from public.group_event_rsvps r
      where r.event_id = v_event.id and r.status in ('going', 'interested')
    loop
      perform public.enqueue_notification(
        v_target,
        'event_reminder',
        'Evento chegando',
        'Um evento do seu grupo comeca em breve.',
        jsonb_build_object(
          'route', '/groups/' || v_event.group_id::text,
          'event_id', v_event.id
        )
      );
      v_count := v_count + 1;
    end loop;

    update public.group_events
    set reminder_sent_at = now()
    where id = v_event.id;
  end loop;

  return jsonb_build_object('reminders', v_count);
end;
$$;

revoke all on function public.enqueue_event_reminders()
  from public, anon, authenticated;
grant execute on function public.enqueue_event_reminders() to service_role;
