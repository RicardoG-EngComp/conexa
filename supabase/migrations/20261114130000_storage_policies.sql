-- Storage (1.0.14): buckets e policies de arquivos.
-- profile-media: privado, escrita apenas na pasta do proprio usuario.
-- stickers: leitura publica, escrita apenas admin.

insert into storage.buckets (id, name, public)
values
  ('profile-media', 'profile-media', false),
  ('stickers', 'stickers', true)
on conflict (id) do update set public = excluded.public;

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'profile-media';

update storage.buckets
set file_size_limit = 2097152,
    allowed_mime_types = array['image/png', 'image/webp', 'image/gif']
where id = 'stickers';

-- @@

drop policy if exists "profile_media_select_auth" on storage.objects;
create policy "profile_media_select_auth" on storage.objects
  for select to authenticated
  using (bucket_id = 'profile-media');

drop policy if exists "profile_media_insert_own" on storage.objects;
create policy "profile_media_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_media_update_own" on storage.objects;
create policy "profile_media_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_media_delete_own" on storage.objects;
create policy "profile_media_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- @@

drop policy if exists "stickers_select_auth" on storage.objects;
create policy "stickers_select_auth" on storage.objects
  for select to authenticated
  using (bucket_id = 'stickers');

drop policy if exists "stickers_insert_admin" on storage.objects;
create policy "stickers_insert_admin" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'stickers' and public.is_admin_user(auth.uid()));

drop policy if exists "stickers_update_admin" on storage.objects;
create policy "stickers_update_admin" on storage.objects
  for update to authenticated
  using (bucket_id = 'stickers' and public.is_admin_user(auth.uid()))
  with check (bucket_id = 'stickers' and public.is_admin_user(auth.uid()));

drop policy if exists "stickers_delete_admin" on storage.objects;
create policy "stickers_delete_admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'stickers' and public.is_admin_user(auth.uid()));
