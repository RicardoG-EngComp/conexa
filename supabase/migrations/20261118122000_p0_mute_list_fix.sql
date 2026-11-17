-- P0 fix: listar mutes mesmo se o alvo estiver suspenso ou bloqueado.
-- O usuario precisa conseguir remover o silenciamento.

create or replace function public.list_muted_users()
returns table (
  id uuid,
  display_name text,
  avatar_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.display_name, p.avatar_url
  from public.user_mutes m
  join public.profiles p on p.id = m.muted_id
  where m.muter_id = auth.uid()
  order by m.created_at desc;
$$;
grant execute on function public.list_muted_users() to authenticated;
