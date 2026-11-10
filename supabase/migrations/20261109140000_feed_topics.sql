-- Bloco 2 (dados do feed): topicos estruturados, group_id em posts,
-- feeds Para Voce/Conexao com relevancia transparente e RLS.

create table if not exists public.topics (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('course', 'campus', 'event_category')),
  slug text not null,
  label text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (kind, slug)
);

alter table public.topics enable row level security;

drop policy if exists "topics_select_auth" on public.topics;
create policy "topics_select_auth" on public.topics
  for select to authenticated using (is_active = true);

-- @@

insert into public.topics (kind, slug, label, sort_order)
values
  ('campus', 'vicosa', 'Viçosa', 1),
  ('campus', 'florestal', 'Florestal', 2),
  ('campus', 'rio-paranaiba', 'Rio Paranaíba', 3)
on conflict (kind, slug) do nothing;

insert into public.topics (kind, slug, label, sort_order)
values
  ('event_category', 'academico', 'Acadêmico', 1),
  ('event_category', 'cultural', 'Cultural', 2),
  ('event_category', 'esportivo', 'Esportivo', 3),
  ('event_category', 'festa', 'Festa', 4),
  ('event_category', 'carreira', 'Carreira', 5),
  ('event_category', 'extensao', 'Extensão', 6),
  ('event_category', 'social', 'Social', 7),
  ('event_category', 'outro', 'Outro', 8)
on conflict (kind, slug) do nothing;

insert into public.topics (kind, slug, label, sort_order)
select
  'course',
  replace(public.normalize_group_name(t.label), ' ', '-'),
  t.label,
  t.ord
from unnest(array[
  'Administração',
  'Agronegócio',
  'Agronomia',
  'Arquitetura e Urbanismo',
  'Bacharelado em Psicologia',
  'Bioquímica',
  'Ciência da Computação',
  'Ciência de Dados',
  'Ciência e Tecnologia de Laticínios',
  'Ciências Biológicas',
  'Ciências Contábeis',
  'Ciências Econômicas',
  'Ciências Sociais',
  'Comunicação Social/Jornalismo',
  'Cooperativismo',
  'Dança',
  'Direito',
  'Economia Doméstica',
  'Educação Física',
  'Educação Infantil',
  'Enfermagem',
  'Engenharia Agrícola e Ambiental',
  'Engenharia Ambiental',
  'Engenharia Civil',
  'Engenharia de Agrimensura e Cartográfica',
  'Engenharia de Alimentos',
  'Engenharia de Produção',
  'Engenharia de Robôs',
  'Engenharia Elétrica',
  'Engenharia Física',
  'Engenharia Florestal',
  'Engenharia Mecânica',
  'Engenharia Química',
  'Física',
  'Geografia',
  'Gestão do Agronegócio',
  'História',
  'Letras',
  'Matemática',
  'Medicina',
  'Medicina Veterinária',
  'Nutrição',
  'Química',
  'Sistemas de Informação',
  'Zootecnia',
  'Licenciatura em Administração',
  'Licenciatura em Ciências Biológicas',
  'Licenciatura em Ciências Sociais',
  'Licenciatura em Educação',
  'Licenciatura em Educação do Campo',
  'Licenciatura em Física',
  'Licenciatura em Geografia',
  'Licenciatura em História',
  'Licenciatura em Matemática',
  'Licenciatura em Química',
  'Bacharelado em Educação Física',
  'Licenciatura em Educação Física',
  'Pedagogia',
  'Secretariado Executivo Trilíngue',
  'Serviço Social',
  'Ciências de Dados',
  'Ciências de Dados e Inteligência Artificial',
  'Matemática Aplicada e Computacional',
  'Engenharia Ambiental e Sanitária',
  'Tecnologia em Gestão Ambiental',
  'Ciência e Tecnologia de Alimentos',
  'Ciências Biológicas – Ênfase em Conservação da Biodiversidade'
]) with ordinality as t(label, ord)
on conflict (kind, slug) do nothing;

-- @@

alter table public.posts
  add column if not exists group_id uuid references public.groups(id) on delete cascade;

alter table public.posts
  drop constraint if exists posts_group_visibility_check;
alter table public.posts
  add constraint posts_group_visibility_check
  check (group_id is null or visibility = 'public');

create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_group_id_idx on public.posts (group_id);

create table if not exists public.post_topics (
  post_id uuid not null references public.posts(id) on delete cascade,
  topic_id uuid not null references public.topics(id) on delete cascade,
  primary key (post_id, topic_id)
);

create index if not exists post_topics_topic_idx
  on public.post_topics (topic_id, post_id);

alter table public.post_topics enable row level security;

-- @@

create or replace function public.is_own_post(p uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.posts po where po.id = p and po.user_id = auth.uid()
  );
$$;
grant execute on function public.is_own_post(uuid) to authenticated;

drop policy if exists "post_topics_select" on public.post_topics;
create policy "post_topics_select" on public.post_topics
  for select to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_topics_insert_own" on public.post_topics;
create policy "post_topics_insert_own" on public.post_topics
  for insert to authenticated with check (public.is_own_post(post_id));

drop policy if exists "post_topics_delete_own" on public.post_topics;
create policy "post_topics_delete_own" on public.post_topics
  for delete to authenticated using (public.is_own_post(post_id));

create or replace function public.enforce_post_topics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_kind text;
  v_count int;
  v_course int;
  v_campus int;
  v_event int;
begin
  if not exists (
    select 1 from public.posts po where po.id = new.post_id and po.user_id = auth.uid()
  ) then raise exception 'nao_e_dono'; end if;

  select t.kind into v_kind
  from public.topics t
  where t.id = new.topic_id and t.is_active;
  if v_kind is null then raise exception 'topico_invalido'; end if;

  select count(*) into v_count from public.post_topics where post_id = new.post_id;
  if v_count >= 5 then raise exception 'maximo_topicos'; end if;

  select count(*) into v_course
  from public.post_topics pt join public.topics t on t.id = pt.topic_id
  where pt.post_id = new.post_id and t.kind = 'course';
  select count(*) into v_campus
  from public.post_topics pt join public.topics t on t.id = pt.topic_id
  where pt.post_id = new.post_id and t.kind = 'campus';
  select count(*) into v_event
  from public.post_topics pt join public.topics t on t.id = pt.topic_id
  where pt.post_id = new.post_id and t.kind = 'event_category';

  if v_kind = 'course' and v_course >= 1 then raise exception 'curso_duplicado'; end if;
  if v_kind = 'campus' and v_campus >= 1 then raise exception 'campus_duplicado'; end if;
  if v_kind = 'event_category' and v_event >= 3 then raise exception 'muitas_categorias'; end if;

  return new;
end;
$$;

drop trigger if exists post_topics_enforce on public.post_topics;
create trigger post_topics_enforce
before insert on public.post_topics
for each row execute function public.enforce_post_topics();

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
      and po.hidden_at is null
      and pr.account_status = 'active'
      and not public.is_blocked(auth.uid(), po.user_id)
      and (
        po.user_id = auth.uid()
        or (po.group_id is not null and public.can_view_group(po.group_id))
        or (po.group_id is null and pr.profile_private = false and po.visibility = 'public')
        or (po.group_id is null and public.is_connection(auth.uid(), po.user_id))
      )
  );
$$;

-- @@
-- Feeds

create or replace function public.feed_for_you(
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  score int,
  course_match boolean,
  campus_match boolean,
  interest_match boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_course text;
  v_campus text;
  v_interests text[];
begin
  if v_me is null then return; end if;

  select p.course, p.campus, p.interests
  into v_course, v_campus, v_interests
  from public.profiles p
  where p.id = v_me;

  return query
  with m as (
    select
      po.id,
      po.created_at,
      case when v_course is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'course'
          and lower(tp.label) = lower(v_course)
      ) then 1 else 0 end as cm,
      case when v_campus is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'campus'
          and lower(tp.label) = lower(v_campus)
      ) then 1 else 0 end as cam,
      case when v_interests is not null and exists (
        select 1 from public.post_topics pt
        join public.topics tp on tp.id = pt.topic_id
        where pt.post_id = po.id and tp.kind = 'event_category'
          and lower(tp.label) in (select lower(x) from unnest(v_interests) x)
      ) then 1 else 0 end as im
    from public.posts po
    where po.hidden_at is null
      and po.created_at > now() - interval '30 days'
      and po.user_id <> v_me
      and not public.is_blocked(v_me, po.user_id)
      and (
        (
          po.group_id is null
          and po.visibility = 'public'
          and exists (
            select 1 from public.profiles pr
            where pr.id = po.user_id
              and pr.account_status = 'active'
              and pr.profile_private = false
          )
        )
        or (
          po.group_id is not null
          and exists (
            select 1 from public.groups g
            where g.id = po.group_id
              and g.archived_at is null
              and g.visibility = 'public'
              and g.public_approval = 'approved'
              and g.is_official
              and g.under_review = false
          )
        )
      )
  )
  select
    m.id,
    (3*m.cm + 2*m.cam + 2*m.im
      + case when m.created_at > now() - interval '24 hours' then 1 else 0 end
      + case when m.created_at > now() - interval '7 days' then 1 else 0 end)::int,
    m.cm = 1,
    m.cam = 1,
    m.im = 1
  from m
  order by 2 desc, m.created_at desc, m.id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.feed_for_you(int, int) to authenticated;

-- @@

create or replace function public.feed_connections(
  p_limit int default 30,
  p_offset int default 0
)
returns table (
  post_id uuid,
  source text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then return; end if;

  return query
  select x.post_id, x.source
  from (
    select po.id as post_id, 'own'::text as source, po.created_at
    from public.posts po
    where po.user_id = v_me
      and po.group_id is null
      and po.hidden_at is null

    union all

    select po.id, 'connection', po.created_at
    from public.posts po
    join public.connections c
      on c.status = 'accepted'
      and (
        (c.requester_id = v_me and c.addressee_id = po.user_id)
        or (c.requester_id = po.user_id and c.addressee_id = v_me)
      )
    where po.group_id is null
      and po.hidden_at is null
      and not public.is_blocked(v_me, po.user_id)
      and exists (
        select 1 from public.profiles pr
        where pr.id = po.user_id and pr.account_status = 'active'
      )

    union all

    select po.id, 'group_followed', po.created_at
    from public.posts po
    join public.group_followers gf
      on gf.group_id = po.group_id and gf.user_id = v_me
    join public.groups g
      on g.id = po.group_id
      and g.archived_at is null
      and g.visibility = 'public'
      and g.public_approval = 'approved'
      and g.is_official
      and g.under_review = false
    where po.hidden_at is null
      and not public.is_blocked(v_me, po.user_id)
  ) x
  order by x.created_at desc, x.post_id
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
end;
$$;
grant execute on function public.feed_connections(int, int) to authenticated;
