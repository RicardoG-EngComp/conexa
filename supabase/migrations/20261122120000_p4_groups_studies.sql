-- P4: grupos e estudos (chat de grupo, eventos, analytics de grupo, Q&A,
-- materiais salvos e avaliacoes).

-- @@

-- 1) Chat vinculado ao grupo do campus.

alter table public.conversations
  add column if not exists group_id uuid references public.groups(id) on delete cascade;

create unique index if not exists conversations_group_chat_unique
  on public.conversations (group_id)
  where group_id is not null;

alter table public.conversations
  drop constraint if exists conversations_kind_check;
alter table public.conversations
  add constraint conversations_kind_check
  check (kind in ('direct', 'group', 'group_chat'));

alter table public.conversations
  drop constraint if exists conversations_title_check;
alter table public.conversations
  add constraint conversations_title_check
  check (
    (kind = 'direct' and title is null)
    or (
      kind in ('group', 'group_chat')
      and char_length(btrim(title)) between 3 and 80
    )
  );

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

create or replace function public.sync_group_chat_member()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
  v_conv uuid;
  v_owner uuid;
  v_user uuid;
begin
  if tg_op = 'DELETE' then
    v_group := old.group_id;
    v_user := old.user_id;
  else
    v_group := new.group_id;
    v_user := new.user_id;
  end if;

  select id into v_conv from public.conversations where group_id = v_group;
  if v_conv is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE' then
    delete from public.conversation_participants
    where conversation_id = v_conv and user_id = v_user;
    return old;
  end if;

  if new.status <> 'active' then
    delete from public.conversation_participants
    where conversation_id = v_conv and user_id = v_user;
  else
    select owner_id into v_owner from public.groups where id = v_group;
    insert into public.conversation_participants (conversation_id, user_id, role)
    values (
      v_conv,
      v_user,
      case when v_user = v_owner then 'owner' else 'member' end
    )
    on conflict (conversation_id, user_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists group_members_sync_chat on public.group_members;
create trigger group_members_sync_chat
after insert or update of status or delete on public.group_members
for each row execute function public.sync_group_chat_member();

create or replace function public.sync_group_chat_title()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set title = new.name, updated_at = now()
  where group_id = new.id and kind = 'group_chat';
  return new;
end;
$$;

drop trigger if exists groups_sync_chat_title on public.groups;
create trigger groups_sync_chat_title
after update of name on public.groups
for each row execute function public.sync_group_chat_title();

-- @@

-- 2) Eventos de grupo.

create table if not exists public.group_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  description text check (description is null or char_length(description) <= 2000),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  location text check (location is null or char_length(location) <= 160),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);

create index if not exists group_events_group_start_idx
  on public.group_events (group_id, starts_at);

alter table public.group_events enable row level security;

drop policy if exists "group_events_select_visible" on public.group_events;
create policy "group_events_select_visible" on public.group_events
  for select to authenticated
  using (public.can_view_group(group_id));

create or replace function public.create_group_event(
  p_group_id uuid,
  p_title text,
  p_description text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_location text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.has_group_permission(p_group_id, 'manage_group') then
    raise exception 'forbidden';
  end if;
  if char_length(v_title) < 3 or char_length(v_title) > 120 then
    raise exception 'titulo_invalido';
  end if;
  if p_description is not null and char_length(p_description) > 2000 then
    raise exception 'descricao_invalida';
  end if;
  if p_location is not null and char_length(p_location) > 160 then
    raise exception 'local_invalido';
  end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at < p_starts_at then
    raise exception 'data_invalida';
  end if;

  insert into public.group_events (
    group_id, created_by, title, description, starts_at, ends_at, location
  ) values (
    p_group_id,
    auth.uid(),
    v_title,
    nullif(btrim(coalesce(p_description, '')), ''),
    p_starts_at,
    p_ends_at,
    nullif(btrim(coalesce(p_location, '')), '')
  ) returning id into v_id;

  return jsonb_build_object('id', v_id);
end;
$$;
grant execute on function public.create_group_event(
  uuid, text, text, timestamptz, timestamptz, text
) to authenticated;

create or replace function public.delete_group_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select group_id into v_group from public.group_events where id = p_event_id;
  if v_group is null then raise exception 'evento_inexistente'; end if;
  if not public.has_group_permission(v_group, 'manage_group') then
    raise exception 'forbidden';
  end if;

  delete from public.group_events where id = p_event_id;
  return jsonb_build_object('deleted', true);
end;
$$;
grant execute on function public.delete_group_event(uuid) to authenticated;

-- @@

-- 3) Analytics agregado do grupo.

create or replace function public.group_analytics(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid := auth.uid();
  v_since timestamptz := now() - interval '30 days';
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public.can_view_group(p_group_id) then
    raise exception 'grupo_indisponivel';
  end if;
  if not public.is_group_member(p_group_id, v_me)
     and not public.is_admin_user(v_me) then
    raise exception 'forbidden';
  end if;

  return jsonb_build_object(
    'members', (
      select count(*) from public.group_members
      where group_id = p_group_id and status = 'active'
    ),
    'followers', (
      select count(*) from public.group_followers where group_id = p_group_id
    ),
    'posts_30d', (
      select count(*) from public.posts
      where group_id = p_group_id and created_at >= v_since
        and hidden_at is null
    ),
    'comments_30d', (
      select count(*) from public.comments c
      join public.posts p on p.id = c.post_id
      where p.group_id = p_group_id and c.created_at >= v_since
        and c.hidden_at is null and p.hidden_at is null
    ),
    'likes_30d', (
      select count(*) from public.likes l
      join public.posts p on p.id = l.post_id
      where p.group_id = p_group_id and l.created_at >= v_since
        and p.hidden_at is null
    ),
    'messages_30d', (
      select count(*) from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where c.group_id = p_group_id and m.created_at >= v_since
        and m.hidden_at is null
    ),
    'events_upcoming', (
      select count(*) from public.group_events
      where group_id = p_group_id and ends_at >= now()
    )
  );
end;
$$;
grant execute on function public.group_analytics(uuid) to authenticated;

-- @@

-- 4) Q&A de estudos.

create table if not exists public.study_questions (
  id uuid primary key default gen_random_uuid(),
  discipline_id uuid not null references public.disciplines(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 5 and 160),
  content text not null check (char_length(content) between 10 and 4000),
  status text not null default 'open'
    check (status in ('open', 'resolved', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists study_questions_discipline_idx
  on public.study_questions (discipline_id, created_at desc);

alter table public.study_questions enable row level security;

drop policy if exists "study_questions_select" on public.study_questions;
create policy "study_questions_select" on public.study_questions
  for select to authenticated
  using (
    public.is_active_user(auth.uid())
    and status <> 'hidden'
    and not public.is_blocked(auth.uid(), author_id)
  );

drop policy if exists "study_questions_insert_own" on public.study_questions;
create policy "study_questions_insert_own" on public.study_questions
  for insert to authenticated
  with check (author_id = auth.uid() and status = 'open');

create table if not exists public.study_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.study_questions(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  accepted boolean not null default false,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists study_answers_question_idx
  on public.study_answers (question_id, created_at);

alter table public.study_answers enable row level security;

drop policy if exists "study_answers_select" on public.study_answers;
create policy "study_answers_select" on public.study_answers
  for select to authenticated
  using (
    hidden_at is null
    and public.is_active_user(auth.uid())
    and not public.is_blocked(auth.uid(), author_id)
    and exists (
      select 1 from public.study_questions q
      where q.id = question_id and q.status <> 'hidden'
    )
  );

drop policy if exists "study_answers_insert_own" on public.study_answers;
create policy "study_answers_insert_own" on public.study_answers
  for insert to authenticated
  with check (author_id = auth.uid() and hidden_at is null and accepted = false);

create table if not exists public.study_answer_votes (
  answer_id uuid not null references public.study_answers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (answer_id, user_id)
);

alter table public.study_answer_votes enable row level security;

drop policy if exists "study_answer_votes_select_own" on public.study_answer_votes;
create policy "study_answer_votes_select_own" on public.study_answer_votes
  for select to authenticated using (user_id = auth.uid());

create or replace function public.enforce_study_content_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_text text;
  v_category text;
begin
  if tg_table_name = 'study_questions' then
    v_text := coalesce(new.title, '') || ' ' || coalesce(new.content, '');
  else
    v_text := coalesce(new.content, '');
  end if;

  v_category := public.content_policy_category(v_text);
  if v_category is not null then
    insert into public.moderation_events
      (user_id, content_type, content_id, category, snippet, action)
    values
      (auth.uid(), tg_table_name, new.id, v_category, left(v_text, 200), 'blocked');
    raise exception 'conteudo_proibido:%', v_category;
  end if;

  return new;
end;
$$;

drop trigger if exists study_questions_content_policy on public.study_questions;
create trigger study_questions_content_policy
before insert or update of title, content on public.study_questions
for each row execute function public.enforce_study_content_policy();

drop trigger if exists study_answers_content_policy on public.study_answers;
create trigger study_answers_content_policy
before insert or update of content on public.study_answers
for each row execute function public.enforce_study_content_policy();

drop trigger if exists study_questions_active_guidelines on public.study_questions;
create trigger study_questions_active_guidelines
before insert on public.study_questions
for each row execute function public.enforce_active_guidelines();

drop trigger if exists study_answers_active_guidelines on public.study_answers;
create trigger study_answers_active_guidelines
before insert on public.study_answers
for each row execute function public.enforce_active_guidelines();

create or replace function public.accept_study_answer(p_answer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_answer public.study_answers%rowtype;
  v_question public.study_questions%rowtype;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into v_answer from public.study_answers where id = p_answer_id;
  if v_answer.id is null then raise exception 'resposta_inexistente'; end if;
  select * into v_question from public.study_questions where id = v_answer.question_id;
  if v_question.id is null or v_question.author_id <> auth.uid() then
    raise exception 'forbidden';
  end if;

  update public.study_answers
  set accepted = false, updated_at = now()
  where question_id = v_answer.question_id and accepted;

  update public.study_answers
  set accepted = true, updated_at = now()
  where id = p_answer_id;

  update public.study_questions
  set status = 'resolved', updated_at = now()
  where id = v_answer.question_id;

  return jsonb_build_object('accepted', true);
end;
$$;
grant execute on function public.accept_study_answer(uuid) to authenticated;

create or replace function public.toggle_study_answer_vote(p_answer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_answer public.study_answers%rowtype;
  v_exists boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  select * into v_answer from public.study_answers where id = p_answer_id;
  if v_answer.id is null or v_answer.hidden_at is not null then
    raise exception 'resposta_inexistente';
  end if;
  if not exists (
    select 1 from public.study_questions q
    where q.id = v_answer.question_id and q.status <> 'hidden'
  ) then
    raise exception 'pergunta_indisponivel';
  end if;

  select exists (
    select 1 from public.study_answer_votes
    where answer_id = p_answer_id and user_id = auth.uid()
  ) into v_exists;

  if v_exists then
    delete from public.study_answer_votes
    where answer_id = p_answer_id and user_id = auth.uid();
  else
    insert into public.study_answer_votes (answer_id, user_id)
    values (p_answer_id, auth.uid())
    on conflict do nothing;
  end if;

  return jsonb_build_object('voted', not v_exists);
end;
$$;
grant execute on function public.toggle_study_answer_vote(uuid)
  to authenticated;

create or replace function public.study_answer_results(p_question_id uuid)
returns table (
  answer_id uuid,
  votes bigint,
  my_vote boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    a.id,
    count(v.user_id),
    coalesce(bool_or(v.user_id = auth.uid()), false)
  from public.study_answers a
  left join public.study_answer_votes v on v.answer_id = a.id
  where a.question_id = p_question_id and a.hidden_at is null
  group by a.id;
$$;
grant execute on function public.study_answer_results(uuid) to authenticated;

create or replace function public.delete_study_answer(p_answer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_answer public.study_answers%rowtype;
  v_question_author uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into v_answer from public.study_answers where id = p_answer_id;
  if v_answer.id is null then raise exception 'resposta_inexistente'; end if;
  select author_id into v_question_author
  from public.study_questions where id = v_answer.question_id;

  if v_answer.author_id <> auth.uid()
     and v_question_author <> auth.uid()
     and not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  delete from public.study_answers where id = p_answer_id;
  return jsonb_build_object('deleted', true);
end;
$$;
grant execute on function public.delete_study_answer(uuid) to authenticated;

-- @@

-- 5) Materiais salvos e avaliacoes.

create table if not exists public.study_material_saves (
  user_id uuid not null references auth.users(id) on delete cascade,
  material_id uuid not null references public.study_materials(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, material_id)
);

alter table public.study_material_saves enable row level security;

drop policy if exists "study_material_saves_select_own"
  on public.study_material_saves;
create policy "study_material_saves_select_own"
  on public.study_material_saves
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "study_material_saves_insert_own"
  on public.study_material_saves;
create policy "study_material_saves_insert_own"
  on public.study_material_saves
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.study_materials m
      where m.id = material_id and m.status = 'approved' and m.hidden_at is null
    )
  );

drop policy if exists "study_material_saves_delete_own"
  on public.study_material_saves;
create policy "study_material_saves_delete_own"
  on public.study_material_saves
  for delete to authenticated using (user_id = auth.uid());

create table if not exists public.study_material_ratings (
  material_id uuid not null references public.study_materials(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (material_id, user_id)
);

alter table public.study_material_ratings enable row level security;

drop policy if exists "study_material_ratings_select_own"
  on public.study_material_ratings;
create policy "study_material_ratings_select_own"
  on public.study_material_ratings
  for select to authenticated using (user_id = auth.uid());

create or replace function public.rate_study_material(
  p_material_id uuid,
  p_rating int
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if p_rating < 1 or p_rating > 5 then raise exception 'nota_invalida'; end if;
  if not exists (
    select 1 from public.study_materials m
    where m.id = p_material_id and m.status = 'approved' and m.hidden_at is null
  ) then
    raise exception 'material_inacessivel';
  end if;

  insert into public.study_material_ratings (material_id, user_id, rating)
  values (p_material_id, auth.uid(), p_rating)
  on conflict (material_id, user_id) do update
    set rating = excluded.rating, updated_at = now();

  return jsonb_build_object('rating', p_rating);
end;
$$;
grant execute on function public.rate_study_material(uuid, int) to authenticated;

create or replace function public.study_material_rating(p_material_id uuid)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'average', coalesce(avg(rating)::numeric(3,2), 0),
    'count', count(*),
    'my_rating', coalesce((
      select max(rating) from public.study_material_ratings
      where material_id = p_material_id and user_id = auth.uid()
    ), 0)
  )
  from public.study_material_ratings
  where material_id = p_material_id;
$$;
grant execute on function public.study_material_rating(uuid) to authenticated;
