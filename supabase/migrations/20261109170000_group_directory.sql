-- Bloco 6 (interface de grupos): estatisticas e diretorio publico de grupos.

create or replace function public.group_stats(p_group_id uuid)
returns table (member_count bigint, follower_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select
    (select count(*) from public.group_members m
     where m.group_id = p_group_id and m.status = 'active'),
    (select count(*) from public.group_followers f
     where f.group_id = p_group_id);
$$;
grant execute on function public.group_stats(uuid) to authenticated;

-- @@

create or replace function public.public_group_directory(p_search text default null)
returns table (
  id uuid,
  name text,
  description text,
  category text,
  campus text,
  is_official boolean,
  member_count bigint,
  follower_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  select
    g.id,
    g.name,
    g.description,
    g.category,
    g.campus,
    g.is_official,
    (select count(*) from public.group_members m
     where m.group_id = g.id and m.status = 'active'),
    (select count(*) from public.group_followers f
     where f.group_id = g.id)
  from public.groups g
  where g.visibility = 'public'
    and g.public_approval = 'approved'
    and g.is_official
    and g.under_review = false
    and g.archived_at is null
    and (
      p_search is null or btrim(p_search) = ''
      or g.name ilike '%' || p_search || '%'
      or g.category ilike '%' || p_search || '%'
      or g.campus ilike '%' || p_search || '%'
    )
  order by g.name;
$$;
grant execute on function public.public_group_directory(text) to authenticated;
