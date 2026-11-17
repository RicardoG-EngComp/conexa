-- P1: operacao admin para forcar publicacao de um agendamento.

create or replace function public.admin_publish_scheduled_post(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.scheduled_posts%rowtype;
begin
  if not public.is_admin_user(auth.uid()) then raise exception 'forbidden'; end if;

  update public.scheduled_posts
  set scheduled_at = now(), updated_at = now()
  where id = p_id and status = 'pending';
  if not found then raise exception 'agendamento_indisponivel'; end if;

  perform public.publish_due_scheduled_posts();

  select * into v_row from public.scheduled_posts where id = p_id;
  return jsonb_build_object(
    'status', v_row.status,
    'post_id', v_row.post_id,
    'error', v_row.error
  );
end;
$$;
grant execute on function public.admin_publish_scheduled_post(uuid)
  to authenticated;
