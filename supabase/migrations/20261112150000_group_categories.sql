-- Categorias oficiais de grupo (1.0.14): Centro Acadêmico, Atlética,
-- Grupo de Estudos, República, Outros. Normaliza dados existentes e valida
-- no servidor (trigger), alem do CHECK.

create or replace function public.normalize_group_category(p text)
returns text
language sql
immutable
set search_path = public
as $$
  select case public.normalize_group_name(coalesce(p, ''))
    when 'centro academico' then 'Centro Acadêmico'
    when 'atletica' then 'Atlética'
    when 'grupo de estudos' then 'Grupo de Estudos'
    when 'republica' then 'República'
    when 'outros' then 'Outros'
    else null
  end;
$$;

-- @@

update public.groups
set category = coalesce(public.normalize_group_category(category), 'Outros');

-- @@

alter table public.groups
  alter column category set default 'Outros';

alter table public.groups
  drop constraint if exists groups_category_check;
alter table public.groups
  add constraint groups_category_check
  check (category in (
    'Centro Acadêmico', 'Atlética', 'Grupo de Estudos', 'República', 'Outros'
  ));

-- @@

create or replace function public.enforce_group_category()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category text;
begin
  v_category := public.normalize_group_category(new.category);
  if v_category is null then
    raise exception 'categoria_invalida';
  end if;
  new.category := v_category;
  return new;
end;
$$;

drop trigger if exists groups_category_enforce on public.groups;
create trigger groups_category_enforce
before insert or update of category on public.groups
for each row execute function public.enforce_group_category();
