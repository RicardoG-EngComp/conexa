-- Canal de feedback: bugs e sugestoes.
-- Regras: RLS por dono/admin, campos do sistema forcados no servidor,
-- limite de 20 envios/24h por tipo, storage privado e exportacao so para admin.

create table if not exists public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 120),
  description text not null
    check (char_length(description) between 10 and 4000),
  steps text check (steps is null or char_length(steps) <= 4000),
  expected text check (expected is null or char_length(expected) <= 2000),
  actual text check (actual is null or char_length(actual) <= 2000),
  platform text check (platform is null or char_length(platform) <= 40),
  app_version text check (app_version is null or char_length(app_version) <= 40),
  screenshot_path text
    check (screenshot_path is null or char_length(screenshot_path) <= 300),
  status text not null default 'new'
    check (status in ('new', 'triaged', 'in_progress', 'fixed', 'wontfix')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bug_reports_number_key unique (number)
);

create index if not exists bug_reports_reporter_created_idx
  on public.bug_reports (reporter_id, created_at desc);

create table if not exists public.suggestions (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 120),
  description text not null
    check (char_length(description) between 10 and 4000),
  problem text check (problem is null or char_length(problem) <= 2000),
  proposal text check (proposal is null or char_length(proposal) <= 2000),
  impact text check (impact is null or char_length(impact) <= 1000),
  platform text check (platform is null or char_length(platform) <= 40),
  app_version text check (app_version is null or char_length(app_version) <= 40),
  status text not null default 'new'
    check (status in ('new', 'analyzed', 'accepted', 'declined', 'implemented')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint suggestions_number_key unique (number)
);

create index if not exists suggestions_reporter_created_idx
  on public.suggestions (reporter_id, created_at desc);

alter table public.bug_reports enable row level security;
alter table public.suggestions enable row level security;

revoke all on table public.bug_reports from anon, authenticated;
revoke all on table public.suggestions from anon, authenticated;

grant select on table public.bug_reports to authenticated;
grant select on table public.suggestions to authenticated;

grant insert (
  id,
  reporter_id,
  title,
  description,
  steps,
  expected,
  actual,
  platform,
  app_version,
  screenshot_path
) on table public.bug_reports to authenticated;

grant insert (
  id,
  reporter_id,
  title,
  description,
  problem,
  proposal,
  impact,
  platform,
  app_version
) on table public.suggestions to authenticated;

grant update (status, updated_at) on table public.bug_reports to authenticated;
grant update (status, updated_at) on table public.suggestions to authenticated;
grant delete on table public.bug_reports to authenticated;
grant delete on table public.suggestions to authenticated;

grant usage on sequence public.bug_reports_number_seq to authenticated;
grant usage on sequence public.suggestions_number_seq to authenticated;

drop policy if exists "bug_reports_insert_own" on public.bug_reports;
create policy "bug_reports_insert_own" on public.bug_reports
  for insert to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "bug_reports_select_own" on public.bug_reports;
create policy "bug_reports_select_own" on public.bug_reports
  for select to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists "bug_reports_select_admin" on public.bug_reports;
create policy "bug_reports_select_admin" on public.bug_reports
  for select to authenticated
  using (public.is_admin_user(auth.uid()));

drop policy if exists "bug_reports_update_admin" on public.bug_reports;
create policy "bug_reports_update_admin" on public.bug_reports
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "bug_reports_delete_admin" on public.bug_reports;
create policy "bug_reports_delete_admin" on public.bug_reports
  for delete to authenticated
  using (public.is_admin_user(auth.uid()));

drop policy if exists "suggestions_insert_own" on public.suggestions;
create policy "suggestions_insert_own" on public.suggestions
  for insert to authenticated
  with check (auth.uid() = reporter_id);

drop policy if exists "suggestions_select_own" on public.suggestions;
create policy "suggestions_select_own" on public.suggestions
  for select to authenticated
  using (auth.uid() = reporter_id);

drop policy if exists "suggestions_select_admin" on public.suggestions;
create policy "suggestions_select_admin" on public.suggestions
  for select to authenticated
  using (public.is_admin_user(auth.uid()));

drop policy if exists "suggestions_update_admin" on public.suggestions;
create policy "suggestions_update_admin" on public.suggestions
  for update to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "suggestions_delete_admin" on public.suggestions;
create policy "suggestions_delete_admin" on public.suggestions
  for delete to authenticated
  using (public.is_admin_user(auth.uid()));

create or replace function public.force_feedback_server_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.status := 'new';
  new.created_at := now();
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.force_feedback_server_fields()
  from public, anon, authenticated;

create or replace function public.validate_bug_report_screenshot_path()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.screenshot_path is not null then
    if new.screenshot_path not like (new.reporter_id::text || '/%')
       or position('..' in new.screenshot_path) > 0 then
      raise exception 'caminho_invalido';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.validate_bug_report_screenshot_path()
  from public, anon, authenticated;

create or replace function public.enforce_bug_report_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if auth.uid() is not null and new.reporter_id is distinct from auth.uid() then
    raise exception 'forbidden';
  end if;

  select count(*) into v_count
  from public.bug_reports
  where reporter_id = new.reporter_id
    and created_at > now() - interval '24 hours';

  if v_count >= 20 then
    raise exception 'limite_feedback';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_bug_report_rate_limit()
  from public, anon, authenticated;

create or replace function public.enforce_suggestion_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if auth.uid() is not null and new.reporter_id is distinct from auth.uid() then
    raise exception 'forbidden';
  end if;

  select count(*) into v_count
  from public.suggestions
  where reporter_id = new.reporter_id
    and created_at > now() - interval '24 hours';

  if v_count >= 20 then
    raise exception 'limite_feedback';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_suggestion_rate_limit()
  from public, anon, authenticated;

create or replace function public.audit_feedback_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    insert into public.audit_log (actor_id, action, target_user_id, metadata)
    values (
      auth.uid(),
      'delete_feedback',
      old.reporter_id,
      jsonb_build_object('kind', tg_table_name, 'number', old.number)
    );
  end if;
  return old;
end;
$$;

revoke all on function public.audit_feedback_delete()
  from public, anon, authenticated;

drop trigger if exists bug_reports_force_fields on public.bug_reports;
create trigger bug_reports_force_fields
  before insert on public.bug_reports
  for each row execute function public.force_feedback_server_fields();

drop trigger if exists bug_reports_rate_limit on public.bug_reports;
create trigger bug_reports_rate_limit
  before insert on public.bug_reports
  for each row execute function public.enforce_bug_report_rate_limit();

drop trigger if exists bug_reports_validate_path on public.bug_reports;
create trigger bug_reports_validate_path
  before insert on public.bug_reports
  for each row execute function public.validate_bug_report_screenshot_path();

drop trigger if exists bug_reports_set_updated_at on public.bug_reports;
create trigger bug_reports_set_updated_at
  before update on public.bug_reports
  for each row execute function public.set_updated_at();

drop trigger if exists bug_reports_audit_delete on public.bug_reports;
create trigger bug_reports_audit_delete
  before delete on public.bug_reports
  for each row execute function public.audit_feedback_delete();

drop trigger if exists suggestions_force_fields on public.suggestions;
create trigger suggestions_force_fields
  before insert on public.suggestions
  for each row execute function public.force_feedback_server_fields();

drop trigger if exists suggestions_rate_limit on public.suggestions;
create trigger suggestions_rate_limit
  before insert on public.suggestions
  for each row execute function public.enforce_suggestion_rate_limit();

drop trigger if exists suggestions_set_updated_at on public.suggestions;
create trigger suggestions_set_updated_at
  before update on public.suggestions
  for each row execute function public.set_updated_at();

drop trigger if exists suggestions_audit_delete on public.suggestions;
create trigger suggestions_audit_delete
  before delete on public.suggestions
  for each row execute function public.audit_feedback_delete();

insert into storage.buckets (id, name, public)
values ('feedback-media', 'feedback-media', false)
on conflict (id) do update set public = false;

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'feedback-media';

drop policy if exists "feedback_media_select_own" on storage.objects;
create policy "feedback_media_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'feedback-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin_user(auth.uid())
    )
  );

drop policy if exists "feedback_media_insert_own" on storage.objects;
create policy "feedback_media_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'feedback-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "feedback_media_delete_own" on storage.objects;
create policy "feedback_media_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'feedback-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create or replace function public.export_feedback(p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_items jsonb;
  v_kind text := lower(coalesce(p_kind, ''));
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  if v_kind = 'bug' then
    select coalesce(jsonb_agg(item order by item_number), '[]'::jsonb)
    into v_items
    from (
      select
        number as item_number,
        jsonb_build_object(
          'protocol', 'BUG-' || lpad(number::text, 6, '0'),
          'number', number,
          'title', title,
          'description', description,
          'steps', steps,
          'expected', expected,
          'actual', actual,
          'platform', platform,
          'app_version', app_version,
          'screenshot_path', screenshot_path,
          'status', status,
          'created_at', created_at,
          'updated_at', updated_at
        ) as item
      from public.bug_reports
      where status in ('new', 'triaged', 'in_progress')
    ) src;
  elsif v_kind = 'suggestion' then
    select coalesce(jsonb_agg(item order by item_number), '[]'::jsonb)
    into v_items
    from (
      select
        number as item_number,
        jsonb_build_object(
          'protocol', 'SUG-' || lpad(number::text, 6, '0'),
          'number', number,
          'title', title,
          'description', description,
          'problem', problem,
          'proposal', proposal,
          'impact', impact,
          'platform', platform,
          'app_version', app_version,
          'status', status,
          'created_at', created_at,
          'updated_at', updated_at
        ) as item
      from public.suggestions
      where status in ('new', 'analyzed', 'accepted')
    ) src;
  else
    raise exception 'tipo_invalido';
  end if;

  return v_items;
end;
$$;

revoke all on function public.export_feedback(text)
  from public, anon, authenticated;
grant execute on function public.export_feedback(text) to authenticated;

notify pgrst, 'reload schema';

