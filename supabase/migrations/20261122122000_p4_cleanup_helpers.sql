-- P4: helpers de limpeza do proprio conteudo.

create or replace function public.remove_study_material_rating(
  p_material_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.study_material_ratings
  where material_id = p_material_id and user_id = auth.uid();
  return jsonb_build_object('removed', true);
end;
$$;
grant execute on function public.remove_study_material_rating(uuid)
  to authenticated;

create or replace function public.delete_study_question(p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select author_id into v_author
  from public.study_questions where id = p_question_id;
  if v_author is null then raise exception 'pergunta_inexistente'; end if;
  if v_author <> auth.uid() and not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  delete from public.study_questions where id = p_question_id;
  return jsonb_build_object('deleted', true);
end;
$$;
grant execute on function public.delete_study_question(uuid)
  to authenticated;
