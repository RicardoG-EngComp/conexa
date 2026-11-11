-- Acoes administrativas de perfil (auditadas), sem expor a tabela profiles.

create or replace function public.admin_set_profile_review(
  p_user_id uuid,
  p_under_review boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'forbidden'; end if;

  update public.profiles
  set profile_under_review = coalesce(p_under_review, false)
  where id = p_user_id;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(), 'set_profile_review', p_user_id,
    jsonb_build_object('under_review', coalesce(p_under_review, false))
  );
end;
$$;
grant execute on function public.admin_set_profile_review(uuid, boolean) to authenticated;

-- @@

create or replace function public.admin_set_account_status(
  p_user_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'forbidden'; end if;
  if p_status not in ('active', 'suspended', 'banned') then
    raise exception 'status invalido';
  end if;

  update public.profiles
  set account_status = p_status
  where id = p_user_id;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(), 'set_account_status', p_user_id,
    jsonb_build_object('status', p_status)
  );
end;
$$;
grant execute on function public.admin_set_account_status(uuid, text) to authenticated;
