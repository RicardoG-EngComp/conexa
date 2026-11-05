create or replace function public.handle_report_autohide()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  severe boolean;
begin
  severe := new.category in (
    'intolerancia_discriminacao',
    'violencia_ameaca',
    'conteudo_sexual_explicito',
    'imagem_nao_consentida',
    'menor_de_idade',
    'direitos_autorais',
    'material_ilegal'
  );

  if not severe then
    return new;
  end if;

  if new.target_type = 'post' and new.target_id is not null then
    update public.posts set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'comment' and new.target_id is not null then
    update public.comments set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'message' and new.target_id is not null then
    update public.messages set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'material' and new.target_id is not null then
    update public.study_materials
    set status = 'hidden', hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'profile' then
    update public.profiles set profile_under_review = true
    where id = new.reported_user_id;
  end if;

  return new;
end;
$$;
