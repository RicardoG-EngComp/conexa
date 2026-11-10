-- Bloco 8 (fix de testes + feature real): dono (ou admin) apaga o proprio
-- grupo. O delete em cascata remove membros, cargos, convites, seguidores,
-- posts do grupo e eventos de auditoria do grupo.

create or replace function public.delete_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select owner_id into v_owner from public.groups where id = p_group_id;
  if v_owner is null then raise exception 'grupo inexistente'; end if;
  if v_owner <> auth.uid() and not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (auth.uid(), 'delete_group', v_owner, jsonb_build_object('group_id', p_group_id));

  delete from public.groups where id = p_group_id;
end;
$$;
grant execute on function public.delete_group(uuid) to authenticated;
