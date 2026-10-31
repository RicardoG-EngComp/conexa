-- Chat: marcador de leitura para contador de nao lidas
alter table public.conversation_participants
  add column if not exists last_read_at timestamptz not null default now();

drop policy if exists "participants_update_own" on public.conversation_participants;
create policy "participants_update_own" on public.conversation_participants
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
