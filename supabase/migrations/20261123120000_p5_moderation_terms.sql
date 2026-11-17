-- P5: termos de moderacao gerenciaveis pelo admin.

create table if not exists public.moderation_terms (
  id uuid primary key default gen_random_uuid(),
  term text not null,
  normalized_term text not null,
  category text not null check (category in (
    'intolerancia_discriminacao',
    'violencia_ameaca',
    'conteudo_sexual_explicito',
    'assedio'
  )),
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (normalized_term, category)
);

alter table public.moderation_terms enable row level security;

drop policy if exists "moderation_terms_select_admin" on public.moderation_terms;
create policy "moderation_terms_select_admin" on public.moderation_terms
  for select to authenticated using (public.is_admin_user(auth.uid()));

drop policy if exists "moderation_terms_insert_admin" on public.moderation_terms;
create policy "moderation_terms_insert_admin" on public.moderation_terms
  for insert to authenticated
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "moderation_terms_update_admin" on public.moderation_terms;
create policy "moderation_terms_update_admin" on public.moderation_terms
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "moderation_terms_delete_admin" on public.moderation_terms;
create policy "moderation_terms_delete_admin" on public.moderation_terms
  for delete to authenticated using (public.is_admin_user(auth.uid()));

create or replace function public.normalize_moderation_term(p_term text)
returns text
language sql
immutable
as $$
  select lower(btrim(regexp_replace(coalesce(p_term, ''), '\s+', ' ', 'g')));
$$;

create or replace function public.validate_moderation_term()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;
  new.term := btrim(coalesce(new.term, ''));
  new.normalized_term := public.normalize_moderation_term(new.term);
  if char_length(new.term) < 2 or char_length(new.term) > 80 then
    raise exception 'termo_invalido';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists moderation_terms_validate on public.moderation_terms;
create trigger moderation_terms_validate
before insert or update on public.moderation_terms
for each row execute function public.validate_moderation_term();

create or replace function public.moderation_term_category(p_content text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select mt.category
  from public.moderation_terms mt
  where mt.active
    and position(mt.normalized_term in lower(coalesce(p_content, ''))) > 0
  order by char_length(mt.normalized_term) desc
  limit 1;
$$;
grant execute on function public.moderation_term_category(text) to authenticated;

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

insert into public.moderation_terms (term, normalized_term, category, active)
values
  ('viado', 'viado', 'intolerancia_discriminacao', true),
  ('bicha', 'bicha', 'intolerancia_discriminacao', true),
  ('traveco', 'traveco', 'intolerancia_discriminacao', true),
  ('retardado', 'retardado', 'intolerancia_discriminacao', true),
  ('mongoloide', 'mongoloide', 'intolerancia_discriminacao', true),
  ('preto imundo', 'preto imundo', 'intolerancia_discriminacao', true),
  ('preta imunda', 'preta imunda', 'intolerancia_discriminacao', true),
  ('macaco imundo', 'macaco imundo', 'intolerancia_discriminacao', true),
  ('vou te matar', 'vou te matar', 'violencia_ameaca', true),
  ('vou te bater', 'vou te bater', 'violencia_ameaca', true),
  ('vou te estuprar', 'vou te estuprar', 'violencia_ameaca', true),
  ('vou acabar com voce', 'vou acabar com voce', 'violencia_ameaca', true),
  ('sei onde voce mora', 'sei onde voce mora', 'violencia_ameaca', true),
  ('vou te pegar', 'vou te pegar', 'violencia_ameaca', true),
  ('vou te encontrar', 'vou te encontrar', 'violencia_ameaca', true),
  ('matar todos', 'matar todos', 'violencia_ameaca', true),
  ('manda nude', 'manda nude', 'conteudo_sexual_explicito', true),
  ('manda nudes', 'manda nudes', 'conteudo_sexual_explicito', true),
  ('manda foto pelada', 'manda foto pelada', 'conteudo_sexual_explicito', true),
  ('manda foto sem roupa', 'manda foto sem roupa', 'conteudo_sexual_explicito', true),
  ('quero ver seu corpo', 'quero ver seu corpo', 'conteudo_sexual_explicito', true),
  ('video de sexo', 'video de sexo', 'conteudo_sexual_explicito', true),
  ('pornografia', 'pornografia', 'conteudo_sexual_explicito', true),
  ('porno', 'porno', 'conteudo_sexual_explicito', true),
  ('onlyfans', 'onlyfans', 'conteudo_sexual_explicito', true),
  ('xvideo', 'xvideo', 'conteudo_sexual_explicito', true),
  ('vagabunda', 'vagabunda', 'assedio', true),
  ('vadia', 'vadia', 'assedio', true),
  ('piranha', 'piranha', 'assedio', true),
  ('otaria', 'otaria', 'assedio', true),
  ('lixo humano', 'lixo humano', 'assedio', true),
  ('nojenta', 'nojenta', 'assedio', true),
  ('nojento', 'nojento', 'assedio', true)
on conflict (normalized_term, category) do nothing;
