-- B1.2 revisado: identidade por e-mail institucional UFV
alter table public.profiles add column if not exists ufv_email text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, ufv_email, birth_date)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data->>'birth_date', '')::date
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.handle_email_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is not null
     and (
       lower(coalesce(new.email, '')) like '%@ufv.br'
       or lower(coalesce(new.email, '')) like '%@alunos.ufv.br'
     ) then
    update public.profiles
      set verification_status = 'verified',
          ufv_email = new.email
      where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
after update of email_confirmed_at on auth.users
for each row execute function public.handle_email_confirmed();
