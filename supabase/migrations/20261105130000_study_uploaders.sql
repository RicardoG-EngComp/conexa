-- Upload de materiais restrito a convidados do piloto (fase 1)

create table if not exists public.study_uploaders (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.study_uploaders enable row level security;

drop policy if exists "study_uploaders_select_own" on public.study_uploaders;
create policy "study_uploaders_select_own" on public.study_uploaders
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin_user(auth.uid()));

drop policy if exists "study_uploaders_admin_write" on public.study_uploaders;
create policy "study_uploaders_admin_write" on public.study_uploaders
  for all to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- @@

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
    and exists (
      select 1 from public.study_uploaders u
      where u.user_id = auth.uid()
    )
  );

-- @@

insert into public.study_uploaders (user_id, granted_by)
values
  ('2f637dba-5547-49c6-83da-791610de7191', '2f637dba-5547-49c6-83da-791610de7191'),
  ('4d97a02e-d7d4-4089-8d64-b1dd9ccf7047', '2f637dba-5547-49c6-83da-791610de7191'),
  ('bcda4901-3f02-4309-8cf2-1d4bcaead394', '2f637dba-5547-49c6-83da-791610de7191')
on conflict (user_id) do nothing;
