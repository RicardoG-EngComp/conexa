-- P7: hub, busca academica, eventos e mapa colaborativo.

-- Busca academica unificada (materiais, disciplinas, professores e Q&A).
create or replace function public.search_study_catalog(
  p_query text,
  p_limit integer default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_query text;
  v_limit integer;
  v_materials jsonb;
  v_disciplines jsonb;
  v_professors jsonb;
  v_questions jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;

  v_limit := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_query := public.normalize_group_name(coalesce(p_query, ''));

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into v_materials
  from (
    select m.id, m.title, m.description, m.kind, m.discipline_id,
           d.name as discipline_name, d.professor_name, m.created_at,
           p.display_name as author_name
    from public.study_materials m
    join public.disciplines d on d.id = m.discipline_id
    left join public.profiles_public p on p.id = m.author_id
    where m.status = 'approved'
      and m.hidden_at is null
      and not public.is_blocked(auth.uid(), m.author_id)
      and (
        v_query = ''
        or public.normalize_group_name(m.title) like '%' || v_query || '%'
        or public.normalize_group_name(coalesce(m.description, '')) like '%' || v_query || '%'
        or public.normalize_group_name(d.name) like '%' || v_query || '%'
        or public.normalize_group_name(coalesce(d.professor_name, '')) like '%' || v_query || '%'
      )
    order by m.created_at desc
    limit v_limit
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into v_disciplines
  from (
    select d.id, d.code, d.name, d.course, d.campus, d.professor_name
    from public.disciplines d
    where v_query = ''
       or public.normalize_group_name(d.name) like '%' || v_query || '%'
       or public.normalize_group_name(coalesce(d.code, '')) like '%' || v_query || '%'
       or public.normalize_group_name(coalesce(d.course, '')) like '%' || v_query || '%'
       or public.normalize_group_name(coalesce(d.professor_name, '')) like '%' || v_query || '%'
    order by d.name
    limit v_limit
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into v_professors
  from (
    select d.professor_name as name,
           jsonb_agg(distinct d.name order by d.name) as disciplines,
           jsonb_agg(distinct d.course) filter (where d.course is not null) as courses
    from public.disciplines d
    where d.professor_name is not null
      and btrim(d.professor_name) <> ''
      and (
        v_query = ''
        or public.normalize_group_name(d.professor_name) like '%' || v_query || '%'
      )
    group by d.professor_name
    order by d.professor_name
    limit v_limit
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  into v_questions
  from (
    select q.id, q.title, q.content, q.status, q.discipline_id,
           d.name as discipline_name, q.created_at
    from public.study_questions q
    join public.disciplines d on d.id = q.discipline_id
    where q.status <> 'hidden'
      and not public.is_blocked(auth.uid(), q.author_id)
      and (
        v_query = ''
        or public.normalize_group_name(q.title) like '%' || v_query || '%'
        or public.normalize_group_name(q.content) like '%' || v_query || '%'
        or public.normalize_group_name(d.name) like '%' || v_query || '%'
        or public.normalize_group_name(coalesce(d.professor_name, '')) like '%' || v_query || '%'
      )
    order by q.created_at desc
    limit v_limit
  ) x;

  return jsonb_build_object(
    'materials', v_materials,
    'disciplines', v_disciplines,
    'professors', v_professors,
    'questions', v_questions
  );
end;
$$;
grant execute on function public.search_study_catalog(text, integer)
  to authenticated;

-- Eventos divulgados no letreiro da busca. Nesta fase: link externo, sem venda.
create table if not exists public.campus_events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 160),
  description text check (description is null or char_length(description) <= 2000),
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  ticket_url text check (ticket_url is null or ticket_url ~* '^https?://'),
  image_url text check (image_url is null or image_url ~* '^https?://'),
  organizer text,
  campus text,
  course text,
  tags text[] not null default '{}',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create index if not exists campus_events_public_idx
  on public.campus_events (status, starts_at)
  where status = 'approved';

alter table public.campus_events enable row level security;

drop policy if exists "campus_events_select_approved" on public.campus_events;
create policy "campus_events_select_approved" on public.campus_events
  for select to authenticated
  using (
    public.is_active_user(auth.uid())
    and (status = 'approved' or created_by = auth.uid() or public.is_admin_user(auth.uid()))
  );

drop policy if exists "campus_events_insert_own" on public.campus_events;
create policy "campus_events_insert_own" on public.campus_events
  for insert to authenticated
  with check (
    public.is_admin_user(auth.uid())
    or (
      created_by = auth.uid()
      and status = 'pending'
      and public.is_active_user(auth.uid())
    )
  );

drop policy if exists "campus_events_admin_update" on public.campus_events;
create policy "campus_events_admin_update" on public.campus_events
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Locais do mapa, com sugestao de usuarios e aprovacao de admin.
create table if not exists public.campus_places (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  description text check (description is null or char_length(description) <= 1000),
  category text not null default 'Outro'
    check (category in (
      'Pavilhão', 'Sala', 'Comida', 'Mercado', 'Farmácia', 'Hospital',
      'Ponto turístico', 'Outro'
    )),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  image_url text check (image_url is null or image_url ~* '^https?://'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists campus_places_public_idx
  on public.campus_places (status, category)
  where status = 'approved';

alter table public.campus_places enable row level security;

drop policy if exists "campus_places_select_approved" on public.campus_places;
create policy "campus_places_select_approved" on public.campus_places
  for select to authenticated
  using (
    public.is_active_user(auth.uid())
    and (status = 'approved' or created_by = auth.uid() or public.is_admin_user(auth.uid()))
  );

drop policy if exists "campus_places_insert_own" on public.campus_places;
create policy "campus_places_insert_own" on public.campus_places
  for insert to authenticated
  with check (
    public.is_admin_user(auth.uid())
    or (
      created_by = auth.uid()
      and status = 'pending'
      and public.is_active_user(auth.uid())
    )
  );

drop policy if exists "campus_places_admin_update" on public.campus_places;
create policy "campus_places_admin_update" on public.campus_places
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));
