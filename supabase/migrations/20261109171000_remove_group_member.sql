-- Bloco 6: remover membro do grupo (gestao de membros).

create or replace function public.remove_group_member(
  p_group_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.has_group_permission(p_group_id, 'manage_members', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if exists (
    select 1 from public.groups g where g.id = p_group_id and g.owner_id = p_user_id
  ) then raise exception 'nao_pode_remover_dono'; end if;
  if p_user_id = auth.uid() then raise exception 'nao_pode_se_remover'; end if;

  update public.group_members
  set status = 'removed', updated_at = now()
  where group_id = p_group_id and user_id = p_user_id and status = 'active';

  delete from public.group_member_roles
  where group_id = p_group_id and user_id = p_user_id;

  perform public.group_audit(p_group_id, 'remove_member', 'group_members', p_user_id);
end;
$$;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;
