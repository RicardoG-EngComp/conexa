-- P5: busca em comentarios, views, anexos/busca de Q&A e comentarios em notas.

-- 1) Busca em comentarios.

alter table public.comments
  add column if not exists search_vector tsvector
    generated always as (to_tsvector('portuguese', coalesce(content, ''))) stored;

create index if not exists comments_search_idx
  on public.comments using gin (search_vector);

create or replace function public.search_comments(
  p_query text,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  comment_id uuid,
  post_id uuid,
  rank real
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_query tsquery;
begin
  if v_me is null or not public.is_active_user(v_me) then return; end if;
  if p_query is null or btrim(p_query) = '' then return; end if;

  v_query := websearch_to_tsquery('portuguese', p_query);

  return query
  select c.id, c.post_id, ts_rank(c.search_vector, v_query)
  from public.comments c
  where c.hidden_at is null
    and c.search_vector @@ v_query
    and public.can_view_post(c.post_id)
    and not public.is_blocked(v_me, c.user_id)
    and not public.is_muted_by(v_me, c.user_id)
    and not public.content_has_muted_word(v_me, c.content)
    and not exists (
      select 1 from public.post_not_interested ni
      where ni.user_id = v_me and ni.post_id = c.post_id
    )
  order by 3 desc, c.created_at desc, c.id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.search_comments(text, int, int) to authenticated;

-- @@

-- 2) Views.

create table if not exists public.post_views (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  viewed_on date not null default (now() at time zone 'utc')::date,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, viewed_on)
);

alter table public.post_views enable row level security;

drop policy if exists "post_views_select_admin" on public.post_views;
create policy "post_views_select_admin" on public.post_views
  for select to authenticated using (public.is_admin_user(auth.uid()));

create or replace function public.record_post_view(p_post_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.can_view_post(p_post_id) then raise exception 'publicacao_inacessivel'; end if;

  insert into public.post_views (post_id, user_id)
  values (p_post_id, auth.uid())
  on conflict do nothing;

  return jsonb_build_object('recorded', true);
end;
$$;
grant execute on function public.record_post_view(uuid) to authenticated;

create or replace function public.my_views_summary(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid := auth.uid();
  v_days int := greatest(1, least(365, coalesce(p_days, 30)));
  v_since date := ((now() at time zone 'utc')::date - v_days + 1);
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(v_me) then raise exception 'conta_inativa'; end if;

  return jsonb_build_object(
    'days', v_days,
    'views', (
      select count(*) from public.post_views v
      join public.posts p on p.id = v.post_id
      where p.user_id = v_me and v.viewed_on >= v_since and p.hidden_at is null
    ),
    'top_posts', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'post_id', t.post_id,
          'preview', left(t.content, 120),
          'views', t.views
        )
        order by t.views desc, t.created_at desc
      )
      from (
        select p.id as post_id, p.content, p.created_at,
          (
            select count(*) from public.post_views v
            where v.post_id = p.id and v.viewed_on >= v_since
          ) as views
        from public.posts p
        where p.user_id = v_me and p.hidden_at is null
        order by views desc, p.created_at desc
        limit 5
      ) t
    ), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.my_views_summary(int) to authenticated;

-- @@

-- 3) Anexos de Q&A.

alter table public.media_objects
  drop constraint if exists media_objects_scope_check;
alter table public.media_objects
  add constraint media_objects_scope_check
  check (scope in ('profile', 'study', 'feed', 'chat', 'qa'));

alter table public.media_objects
  drop constraint if exists media_objects_kind_check;
alter table public.media_objects
  add constraint media_objects_kind_check
  check (
    kind in (
      'avatar', 'photo', 'study_pdf', 'study_image', 'feed_image', 'feed_video',
      'chat_image', 'chat_video', 'chat_file', 'qa_file', 'qa_image'
    )
  );

create table if not exists public.study_question_attachments (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.study_questions(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  object_key text not null unique,
  kind text not null check (kind in ('image', 'file')),
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  name text,
  created_at timestamptz not null default now()
);

create table if not exists public.study_answer_attachments (
  id uuid primary key default gen_random_uuid(),
  answer_id uuid not null references public.study_answers(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  object_key text not null unique,
  kind text not null check (kind in ('image', 'file')),
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0),
  name text,
  created_at timestamptz not null default now()
);

alter table public.study_question_attachments enable row level security;
alter table public.study_answer_attachments enable row level security;

drop policy if exists "study_question_attachments_select"
  on public.study_question_attachments;
create policy "study_question_attachments_select"
  on public.study_question_attachments
  for select to authenticated
  using (
    exists (
      select 1 from public.study_questions q
      where q.id = question_id and q.status <> 'hidden'
    )
  );

drop policy if exists "study_question_attachments_insert"
  on public.study_question_attachments;
create policy "study_question_attachments_insert"
  on public.study_question_attachments
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.study_questions q
      where q.id = question_id and q.author_id = auth.uid()
    )
  );

drop policy if exists "study_answer_attachments_select"
  on public.study_answer_attachments;
create policy "study_answer_attachments_select"
  on public.study_answer_attachments
  for select to authenticated
  using (
    exists (
      select 1 from public.study_answers a
      join public.study_questions q on q.id = a.question_id
      where a.id = answer_id and a.hidden_at is null and q.status <> 'hidden'
    )
  );

drop policy if exists "study_answer_attachments_insert"
  on public.study_answer_attachments;
create policy "study_answer_attachments_insert"
  on public.study_answer_attachments
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and exists (
      select 1 from public.study_answers a
      where a.id = answer_id and a.author_id = auth.uid()
    )
  );

create or replace function public.validate_qa_attachment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id <> auth.uid() then raise exception 'nao_e_dono'; end if;
  if not exists (
    select 1 from public.media_objects mo
    where mo.owner_id = new.owner_id
      and mo.scope = 'qa'
      and mo.object_key = new.object_key
      and mo.deleted_at is null
      and (
        (new.kind = 'image' and mo.kind = 'qa_image')
        or (new.kind = 'file' and mo.kind = 'qa_file')
      )
  ) then
    raise exception 'midia_invalida';
  end if;
  return new;
end;
$$;

drop trigger if exists study_question_attachments_validate
  on public.study_question_attachments;
create trigger study_question_attachments_validate
before insert on public.study_question_attachments
for each row execute function public.validate_qa_attachment();

drop trigger if exists study_answer_attachments_validate
  on public.study_answer_attachments;
create trigger study_answer_attachments_validate
before insert on public.study_answer_attachments
for each row execute function public.validate_qa_attachment();

create or replace function public.filter_visible_qa_media(paths text[])
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(array_agg(distinct x.object_key), '{}'::text[])
  from (
    select a.object_key
    from public.study_question_attachments a
    join public.study_questions q on q.id = a.question_id
    where a.object_key = any(paths) and q.status <> 'hidden'
    union
    select a.object_key
    from public.study_answer_attachments a
    join public.study_answers ans on ans.id = a.answer_id
    join public.study_questions q on q.id = ans.question_id
    where a.object_key = any(paths) and ans.hidden_at is null and q.status <> 'hidden'
  ) x;
$$;
grant execute on function public.filter_visible_qa_media(text[])
  to authenticated;

-- @@

-- 4) Busca em Q&A.

alter table public.study_questions
  add column if not exists search_vector tsvector
    generated always as (
      to_tsvector('portuguese', coalesce(title, '') || ' ' || coalesce(content, ''))
    ) stored;

alter table public.study_answers
  add column if not exists search_vector tsvector
    generated always as (to_tsvector('portuguese', coalesce(content, ''))) stored;

create index if not exists study_questions_search_idx
  on public.study_questions using gin (search_vector);
create index if not exists study_answers_search_idx
  on public.study_answers using gin (search_vector);

create or replace function public.search_study_qa(
  p_discipline_id uuid,
  p_query text,
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  question_id uuid,
  rank real
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_query tsquery;
begin
  if auth.uid() is null or not public.is_active_user(auth.uid()) then return; end if;
  if p_query is null or btrim(p_query) = '' then return; end if;

  v_query := websearch_to_tsquery('portuguese', p_query);

  return query
  select q.id, max(ts_rank(q.search_vector, v_query))
  from public.study_questions q
  left join public.study_answers a
    on a.question_id = q.id and a.hidden_at is null
  where q.discipline_id = p_discipline_id
    and q.status <> 'hidden'
    and (
      q.search_vector @@ v_query
      or a.search_vector @@ v_query
    )
  group by q.id
  order by 2 desc, q.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.search_study_qa(uuid, text, int, int)
  to authenticated;

-- @@

-- 5) Comentario em avaliacao de material.

alter table public.study_material_ratings
  add column if not exists comment text
    check (comment is null or char_length(comment) <= 1000);

create or replace function public.enforce_rating_comment_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category text;
begin
  if new.comment is null or btrim(new.comment) = '' then return new; end if;
  v_category := public.content_policy_category(new.comment);
  if v_category is not null then
    insert into public.moderation_events
      (user_id, content_type, content_id, category, snippet, action)
    values (
      auth.uid(), 'study_material_rating', new.material_id, v_category,
      left(new.comment, 200), 'blocked'
    );
    raise exception 'conteudo_proibido:%', v_category;
  end if;
  return new;
end;
$$;

drop trigger if exists study_material_rating_comment_policy
  on public.study_material_ratings;
create trigger study_material_rating_comment_policy
before insert or update of comment on public.study_material_ratings
for each row execute function public.enforce_rating_comment_policy();

drop function if exists public.rate_study_material(uuid, int);

create or replace function public.rate_study_material(
  p_material_id uuid,
  p_rating int,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if p_rating < 1 or p_rating > 5 then raise exception 'nota_invalida'; end if;
  if p_comment is not null and char_length(p_comment) > 1000 then
    raise exception 'comentario_longo';
  end if;
  if not exists (
    select 1 from public.study_materials m
    where m.id = p_material_id and m.status = 'approved' and m.hidden_at is null
  ) then
    raise exception 'material_inacessivel';
  end if;

  insert into public.study_material_ratings (
    material_id, user_id, rating, comment
  ) values (
    p_material_id, auth.uid(), p_rating, nullif(btrim(coalesce(p_comment, '')), '')
  )
  on conflict (material_id, user_id) do update
    set rating = excluded.rating,
        comment = excluded.comment,
        updated_at = now();

  return jsonb_build_object('rating', p_rating);
end;
$$;
grant execute on function public.rate_study_material(uuid, int, text)
  to authenticated;

create or replace function public.study_material_reviews(p_material_id uuid)
returns table (
  user_id uuid,
  display_name text,
  rating int,
  comment text,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select r.user_id, coalesce(p.display_name, 'Aluno'), r.rating, r.comment,
         r.updated_at
  from public.study_material_ratings r
  left join public.profiles p on p.id = r.user_id
  where r.material_id = p_material_id
    and r.comment is not null
    and btrim(r.comment) <> ''
  order by r.updated_at desc
  limit 20;
$$;
grant execute on function public.study_material_reviews(uuid) to authenticated;
