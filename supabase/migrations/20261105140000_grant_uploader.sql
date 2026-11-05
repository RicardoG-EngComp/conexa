-- Convite de uploaders de estudo pelo admin

create or replace function public.admin_grant_uploader(p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  select id into v_user
  from auth.users
  where lower(email) = lower(btrim(p_email))
  limit 1;

  if v_user is null then
    raise exception 'user_not_found';
  end if;

  insert into public.study_uploaders (user_id, granted_by)
  values (v_user, auth.uid())
  on conflict (user_id) do nothing;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    'grant_study_uploader',
    v_user,
    jsonb_build_object('email', lower(btrim(p_email)))
  );
end;
$$;

grant execute on function public.admin_grant_uploader(text) to authenticated;
