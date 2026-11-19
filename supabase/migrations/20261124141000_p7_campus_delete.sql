-- Permite limpar sugestoes proprias e conteudo de campus pelo admin.

drop policy if exists "campus_events_delete_own_or_admin" on public.campus_events;
create policy "campus_events_delete_own_or_admin" on public.campus_events
  for delete to authenticated
  using (
    public.is_admin_user(auth.uid())
    or (created_by = auth.uid() and status = 'pending')
  );

drop policy if exists "campus_places_delete_own_or_admin" on public.campus_places;
create policy "campus_places_delete_own_or_admin" on public.campus_places
  for delete to authenticated
  using (
    public.is_admin_user(auth.uid())
    or (created_by = auth.uid() and status = 'pending')
  );
