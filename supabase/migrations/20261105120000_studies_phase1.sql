-- Estudos fase 1: disciplinas, materiais, votos, consentimento de upload e moderação

create table if not exists public.disciplines (
  id uuid primary key default gen_random_uuid(),
  code text,
  name text not null,
  course text,
  campus text not null default 'Viçosa',
  semester int,
  professor_name text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (name, campus)
);

alter table public.disciplines enable row level security;

drop policy if exists "disciplines_select_auth" on public.disciplines;
create policy "disciplines_select_auth" on public.disciplines
  for select to authenticated using (true);

drop policy if exists "disciplines_admin_write" on public.disciplines;
create policy "disciplines_admin_write" on public.disciplines
  for all to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- @@

create table if not exists public.study_materials (
  id uuid primary key default gen_random_uuid(),
  discipline_id uuid not null references public.disciplines(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 160),
  description text check (description is null or char_length(description) <= 2000),
  kind text not null check (kind in ('pdf', 'image', 'link')),
  storage_path text,
  external_url text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'hidden')),
  consent_version text not null,
  moderation_note text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (kind = 'link' and external_url is not null and length(btrim(external_url)) > 0)
    or (kind in ('pdf', 'image') and storage_path is not null)
  )
);

alter table public.study_materials enable row level security;

drop policy if exists "study_materials_select" on public.study_materials;
create policy "study_materials_select" on public.study_materials
  for select to authenticated
  using (
    (
      status = 'approved'
      and hidden_at is null
      and not public.is_blocked(auth.uid(), author_id)
    )
    or author_id = auth.uid()
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "study_materials_insert" on public.study_materials;
create policy "study_materials_insert" on public.study_materials
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and status = 'pending'
    and public.is_active_user(auth.uid())
    and public.has_accepted_guidelines(auth.uid())
    and public.is_profile_complete(auth.uid())
    and consent_version is not null
  );

drop policy if exists "study_materials_update_author" on public.study_materials;
create policy "study_materials_update_author" on public.study_materials
  for update to authenticated
  using (author_id = auth.uid() and status in ('pending', 'rejected'))
  with check (author_id = auth.uid());

drop policy if exists "study_materials_update_admin" on public.study_materials;
create policy "study_materials_update_admin" on public.study_materials
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "study_materials_delete_author" on public.study_materials;
create policy "study_materials_delete_author" on public.study_materials
  for delete to authenticated
  using (author_id = auth.uid() and status in ('pending', 'rejected'));

drop policy if exists "study_materials_delete_admin" on public.study_materials;
create policy "study_materials_delete_admin" on public.study_materials
  for delete to authenticated
  using (public.is_admin_user(auth.uid()));

-- @@

create table if not exists public.study_material_votes (
  material_id uuid not null references public.study_materials(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (material_id, user_id)
);

alter table public.study_material_votes enable row level security;

drop policy if exists "study_votes_select" on public.study_material_votes;
create policy "study_votes_select" on public.study_material_votes
  for select to authenticated
  using (
    exists (
      select 1 from public.study_materials m
      where m.id = material_id
        and (
          (m.status = 'approved' and m.hidden_at is null)
          or m.author_id = auth.uid()
          or public.is_admin_user(auth.uid())
        )
    )
  );

drop policy if exists "study_votes_insert" on public.study_material_votes;
create policy "study_votes_insert" on public.study_material_votes
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.study_materials m
      where m.id = material_id
        and m.status = 'approved'
        and m.hidden_at is null
    )
  );

drop policy if exists "study_votes_delete" on public.study_material_votes;
create policy "study_votes_delete" on public.study_material_votes
  for delete to authenticated using (user_id = auth.uid());

-- @@

create table if not exists public.upload_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  version text not null,
  accepted_at timestamptz not null default now()
);

alter table public.upload_consents enable row level security;

drop policy if exists "upload_consents_insert_own" on public.upload_consents;
create policy "upload_consents_insert_own" on public.upload_consents
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "upload_consents_select_own" on public.upload_consents;
create policy "upload_consents_select_own" on public.upload_consents
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin_user(auth.uid()));

-- @@

alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('post', 'comment', 'message', 'profile', 'material'));

-- @@

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
    'menor_de_idade'
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

-- @@

create or replace function public.admin_moderate_content(
  p_target_type text,
  p_target_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  if p_action = 'hide' then
    if p_target_type = 'post' then
      update public.posts set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'message' then
      update public.messages set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'material' then
      update public.study_materials
      set status = 'hidden', hidden_at = now()
      where id = p_target_id;
    elsif p_target_type = 'profile' then
      update public.profiles set profile_under_review = true where id = p_target_id;
    end if;
  elsif p_action = 'restore' then
    if p_target_type = 'post' then
      update public.posts set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'message' then
      update public.messages set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'material' then
      update public.study_materials
      set status = 'approved', hidden_at = null
      where id = p_target_id;
    elsif p_target_type = 'profile' then
      update public.profiles set profile_under_review = false where id = p_target_id;
    end if;
  elsif p_action = 'delete' then
    if p_target_type = 'post' then
      delete from public.posts where id = p_target_id;
    elsif p_target_type = 'comment' then
      delete from public.comments where id = p_target_id;
    elsif p_target_type = 'message' then
      delete from public.messages where id = p_target_id;
    elsif p_target_type = 'material' then
      delete from public.study_materials where id = p_target_id;
    end if;
  else
    raise exception 'invalid action';
  end if;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    p_action,
    null,
    jsonb_build_object('target_type', p_target_type, 'target_id', p_target_id)
  );
end;
$$;

grant execute on function public.admin_moderate_content(text, uuid, text) to authenticated;

-- @@

create or replace function public.admin_review_material(
  p_material_id uuid,
  p_approve boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.study_materials
  set status = case when p_approve then 'approved' else 'rejected' end,
      approved_by = auth.uid(),
      approved_at = now(),
      moderation_note = p_note
  where id = p_material_id;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    case when p_approve then 'approve_material' else 'reject_material' end,
    null,
    jsonb_build_object('material_id', p_material_id)
  );
end;
$$;

grant execute on function public.admin_review_material(uuid, boolean, text) to authenticated;

-- @@

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
    v_text := coalesce(new.title, '') || ' ' || coalesce(new.description, '');
  else
    v_text := coalesce(new.content, '');
  end if;

  v_category := public.content_policy_category(v_text);
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

drop trigger if exists study_materials_content_policy on public.study_materials;
create trigger study_materials_content_policy
before insert or update of title, description on public.study_materials
for each row execute function public.enforce_content_policy();

-- @@

insert into public.disciplines (code, name, course, campus)
values
  ('calculo-1', 'Cálculo I', 'Engenharias', 'Viçosa'),
  ('fisica-1', 'Física I', 'Engenharias', 'Viçosa'),
  ('quimica-geral', 'Química Geral', 'Engenharias', 'Viçosa'),
  ('estatistica', 'Estatística', 'Engenharias', 'Viçosa'),
  ('algoritmos', 'Algoritmos e Programação', 'Computação', 'Viçosa'),
  ('anatomia-humana', 'Anatomia Humana', 'Saúde', 'Viçosa'),
  ('bioquimica', 'Bioquímica', 'Saúde', 'Viçosa'),
  ('direito-civil-1', 'Direito Civil I', 'Direito', 'Viçosa'),
  ('administracao-geral', 'Administração Geral', 'Administração', 'Viçosa'),
  ('solos-fertilidade', 'Solos e Fertilidade', 'Agronomia', 'Viçosa')
on conflict (name, campus) do nothing;
