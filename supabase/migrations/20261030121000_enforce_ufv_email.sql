-- Permite @ufv.br e @alunos.ufv.br
create or replace function public.enforce_ufv_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is null
     or not (
       lower(new.email) like '%@ufv.br'
       or lower(new.email) like '%@alunos.ufv.br'
     ) then
    raise exception 'Apenas e-mails @ufv.br ou @alunos.ufv.br sao permitidos';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_ufv_email on auth.users;
create trigger enforce_ufv_email
before insert on auth.users
for each row execute function public.enforce_ufv_email();
