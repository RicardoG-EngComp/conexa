-- Bloco 4 (cargos e selo): posts registram grupo, membro autor, cargo e snapshot.
-- O snapshot e gravado no momento da publicacao; se o cargo for retirado depois,
-- o post continua exibindo o nome do cargo ("cargo a epoca").

alter table public.posts
  add column if not exists role_id uuid references public.group_roles(id) on delete set null,
  add column if not exists role_name_snapshot text,
  add column if not exists posted_as_group boolean not null default false;

alter table public.posts
  drop constraint if exists posts_posted_as_group_check;
alter table public.posts
  add constraint posts_posted_as_group_check
  check (posted_as_group = false or group_id is not null);

alter table public.posts
  drop constraint if exists posts_role_seal_check;
alter table public.posts
  add constraint posts_role_seal_check
  check (role_id is null or role_name_snapshot is not null);

create index if not exists posts_role_id_idx on public.posts (role_id);

create or replace function public.enforce_post_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role_group uuid;
  v_role_name text;
begin
  if new.role_id is null then
    if new.group_id is not null then
      raise exception 'cargo_obrigatorio';
    end if;
    new.role_name_snapshot := null;
    new.posted_as_group := false;
    return new;
  end if;

  select r.group_id, r.name into v_role_group, v_role_name
  from public.group_roles r
  where r.id = new.role_id;

  if v_role_group is null then raise exception 'cargo_inexistente'; end if;

  if not exists (
    select 1 from public.group_member_roles mr
    where mr.group_id = v_role_group
      and mr.user_id = new.user_id
      and mr.role_id = new.role_id
  ) then raise exception 'cargo_nao_atribuido'; end if;

  if new.group_id is not null then
    if new.group_id <> v_role_group then raise exception 'cargo_de_outro_grupo'; end if;
    if not public.is_group_member(new.group_id, new.user_id) then
      raise exception 'usuario_nao_membro';
    end if;
    if new.posted_as_group
       and not public.has_group_permission(new.group_id, 'post_as_group', new.user_id) then
      raise exception 'sem_permissao_publicar_em_nome';
    end if;
  else
    new.posted_as_group := false;
    if not exists (
      select 1 from public.groups g
      where g.id = v_role_group
        and g.visibility = 'public'
        and g.public_approval = 'approved'
        and g.is_official
    ) then raise exception 'selo_exige_grupo_publico'; end if;
  end if;

  new.role_name_snapshot := v_role_name;
  return new;
end;
$$;

drop trigger if exists posts_role_enforce on public.posts;
create trigger posts_role_enforce
before insert on public.posts
for each row execute function public.enforce_post_role();
