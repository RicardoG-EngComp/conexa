-- P5 fix: study_materials usa title/description, nao content.

create or replace function public.enforce_content_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_text text := '';
  v_category text;
begin
  if tg_table_name = 'profiles' then
    v_text := coalesce(new.display_name, '') || ' ' ||
              coalesce(new.bio, '') || ' ' ||
              coalesce(new.prompts::text, '');
  elsif tg_table_name = 'conversations' then
    v_text := coalesce(new.request_message, '');
  elsif tg_table_name = 'study_materials' then
    v_text := coalesce(new.title, '') || ' ' ||
              coalesce(new.description, '');
  else
    v_text := coalesce(new.content, '');
  end if;

  v_category := coalesce(
    public.moderation_term_category(v_text),
    public.content_policy_category(v_text)
  );
  if v_category is not null then
    insert into public.moderation_events
      (user_id, content_type, content_id, category, snippet, action)
    values
      (auth.uid(), tg_table_name, new.id, v_category, left(v_text, 200), 'blocked');
    raise exception 'conteudo_proibido:%', v_category;
  end if;

  return new;
end;
$$;
