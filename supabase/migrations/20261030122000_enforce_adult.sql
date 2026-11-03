-- Bloqueia menores de 18 no servidor (data autodeclarada)
create or replace function public.enforce_adult()
returns trigger
language plpgsql
as $$
begin
  if new.birth_date is not null
     and new.birth_date > (current_date - interval '18 years') then
    raise exception 'Cadastro permitido apenas para maiores de 18 anos';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_adult on public.profiles;
create trigger enforce_adult
before insert or update of birth_date on public.profiles
for each row execute function public.enforce_adult();
