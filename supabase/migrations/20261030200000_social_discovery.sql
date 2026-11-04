-- Descobrir Social: visibilidade de posts, conexoes e bloqueios

alter table public.posts
  add column if not exists visibility text not null default 'public'
  check (visibility in ('public', 'friends'));

-- @@

create table if not exists public.connections (
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

alter table public.connections enable row level security;

-- @@

drop policy if exists "connections_select_own" on public.connections;
create policy "connections_select_own" on public.connections
  for select to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

drop policy if exists "connections_insert_own" on public.connections;
create policy "connections_insert_own" on public.connections
  for insert to authenticated with check (requester_id = auth.uid());

drop policy if exists "connections_update_addressee" on public.connections;
create policy "connections_update_addressee" on public.connections
  for update to authenticated
  using (addressee_id = auth.uid())
  with check (addressee_id = auth.uid());

drop policy if exists "connections_delete_own" on public.connections;
create policy "connections_delete_own" on public.connections
  for delete to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- @@

create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

-- @@

drop policy if exists "blocks_select_own" on public.blocks;
create policy "blocks_select_own" on public.blocks
  for select to authenticated using (blocker_id = auth.uid());

drop policy if exists "blocks_insert_own" on public.blocks;
create policy "blocks_insert_own" on public.blocks
  for insert to authenticated with check (blocker_id = auth.uid());

drop policy if exists "blocks_delete_own" on public.blocks;
create policy "blocks_delete_own" on public.blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- @@

create or replace function public.is_connection(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.connections
    where status = 'accepted'
      and (
        (requester_id = a and addressee_id = b)
        or (requester_id = b and addressee_id = a)
      )
  );
$$;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

-- @@

create or replace function public.is_profile_complete(user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = user_id
      and p.display_name is not null and length(btrim(p.display_name)) > 0
      and p.course is not null and length(btrim(p.course)) > 0
      and p.campus is not null and length(btrim(p.campus)) > 0
      and p.avatar_url is not null and length(btrim(p.avatar_url)) > 0
  );
$$;

-- @@

create or replace function public.can_view_post(post_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.posts po
    join public.profiles pr on pr.id = po.user_id
    where po.id = post_id
      and not public.is_blocked(auth.uid(), po.user_id)
      and (
        po.user_id = auth.uid()
        or (pr.profile_private = false and po.visibility = 'public')
        or public.is_connection(auth.uid(), po.user_id)
      )
  );
$$;

-- @@

create or replace function public.conversation_has_block(conv_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.conversation_participants p1
    join public.conversation_participants p2
      on p2.conversation_id = p1.conversation_id
     and p2.user_id <> p1.user_id
    where p1.conversation_id = conv_id
      and p1.user_id = auth.uid()
      and public.is_blocked(p1.user_id, p2.user_id)
  );
$$;

-- @@

drop policy if exists "posts_select_auth" on public.posts;
drop policy if exists "posts_select_visibility" on public.posts;
create policy "posts_select_visibility" on public.posts
  for select to authenticated using (public.can_view_post(id));

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.is_profile_complete(auth.uid())
  );

-- @@

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select to authenticated using (public.can_view_post(post_id));

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own" on public.comments
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.is_profile_complete(auth.uid())
    and public.can_view_post(post_id)
  );

-- @@

drop policy if exists "likes_select_auth" on public.likes;
create policy "likes_select_auth" on public.likes
  for select to authenticated using (public.can_view_post(post_id));

drop policy if exists "likes_insert_own" on public.likes;
create policy "likes_insert_own" on public.likes
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.can_view_post(post_id)
  );

-- @@

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
    and not public.conversation_has_block(conversation_id)
  );

-- @@

drop view if exists public.profiles_public;
create view public.profiles_public as
  select p.id, p.display_name, p.course, p.campus, p.bio, p.prompts,
         p.avatar_url, p.photos, p.interests, p.relationship_style,
         p.verification_status, p.profile_private, p.created_at
  from public.profiles p
  where not exists (
    select 1 from public.blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
       or (b.blocker_id = p.id and b.blocked_id = auth.uid())
  );

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;

-- @@

create or replace function public.discover_profiles(
  p_limit int default 30,
  p_offset int default 0,
  p_course text default null,
  p_search text default null
)
returns table (
  id uuid,
  display_name text,
  course text,
  campus text,
  avatar_url text,
  verification_status text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.display_name, p.course, p.campus, p.avatar_url,
         p.verification_status
  from public.profiles p
  where p.id <> auth.uid()
    and p.account_status = 'active'
    and p.display_name is not null and length(btrim(p.display_name)) > 0
    and p.course is not null and length(btrim(p.course)) > 0
    and p.campus is not null and length(btrim(p.campus)) > 0
    and p.avatar_url is not null and length(btrim(p.avatar_url)) > 0
    and (p_course is null or p.course = p_course)
    and (
      p_search is null or btrim(p_search) = ''
      or p.display_name ilike '%' || p_search || '%'
      or p.course ilike '%' || p_search || '%'
    )
    and not public.is_blocked(auth.uid(), p.id)
  order by p.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;

grant execute on function public.discover_profiles(int, int, text, text) to authenticated;

-- @@

create or replace function public.send_connection_request(target_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  existing record;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if target_user = auth.uid() then raise exception 'cannot connect to yourself'; end if;
  if not public.is_profile_complete(auth.uid()) then raise exception 'profile incomplete'; end if;
  if public.is_blocked(auth.uid(), target_user) then raise exception 'blocked'; end if;

  select requester_id, addressee_id, status into existing
  from public.connections
  where (requester_id = auth.uid() and addressee_id = target_user)
     or (requester_id = target_user and addressee_id = auth.uid())
  limit 1;

  if existing.requester_id is not null then
    return jsonb_build_object(
      'status', existing.status,
      'requester', existing.requester_id
    );
  end if;

  insert into public.connections (requester_id, addressee_id, status)
  values (auth.uid(), target_user, 'pending');

  return jsonb_build_object('status', 'pending', 'requester', auth.uid());
end;
$$;

grant execute on function public.send_connection_request(uuid) to authenticated;

-- @@

create or replace function public.respond_connection_request(requester uuid, accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  conv_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.is_blocked(auth.uid(), requester) then raise exception 'blocked'; end if;

  update public.connections
  set status = case when accept then 'accepted' else 'declined' end,
      responded_at = now()
  where requester_id = requester
    and addressee_id = auth.uid()
    and status = 'pending';

  if not found then raise exception 'request not found'; end if;

  if accept then
    select c.id into conv_id
    from public.conversations c
    join public.conversation_participants p1
      on p1.conversation_id = c.id and p1.user_id = auth.uid()
    join public.conversation_participants p2
      on p2.conversation_id = c.id and p2.user_id = requester
    limit 1;

    if conv_id is null then
      insert into public.conversations (status, initiator_id)
      values ('accepted', requester)
      returning id into conv_id;

      insert into public.conversation_participants (conversation_id, user_id)
      values (conv_id, auth.uid()), (conv_id, requester);
    else
      update public.conversations set status = 'accepted' where id = conv_id;
    end if;
  end if;

  return jsonb_build_object(
    'status', case when accept then 'accepted' else 'declined' end,
    'conversation_id', conv_id
  );
end;
$$;

grant execute on function public.respond_connection_request(uuid, boolean) to authenticated;

-- @@

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
  if not public.is_profile_complete(auth.uid()) then raise exception 'profile incomplete'; end if;
  if public.is_blocked(auth.uid(), other_user) then raise exception 'blocked'; end if;
  if message is null or length(btrim(message)) = 0 then raise exception 'message required'; end if;
  if length(message) > 150 then raise exception 'message too long'; end if;

  if public.is_connection(auth.uid(), other_user) then
    select c.id into conv_id
    from public.conversations c
    join public.conversation_participants p1
      on p1.conversation_id = c.id and p1.user_id = auth.uid()
    join public.conversation_participants p2
      on p2.conversation_id = c.id and p2.user_id = other_user
    limit 1;

    if conv_id is null then
      insert into public.conversations (status, initiator_id)
      values ('accepted', auth.uid())
      returning id into conv_id;

      insert into public.conversation_participants (conversation_id, user_id)
      values (conv_id, auth.uid()), (conv_id, other_user);
    else
      update public.conversations set status = 'accepted' where id = conv_id;
    end if;

    return jsonb_build_object('id', conv_id, 'status', 'accepted');
  end if;

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
