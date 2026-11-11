-- Correcao do guard de perfil: em trigger security definer, current_user e o
-- dono, nao o chamador. Usar pg_trigger_depth(): 1 = update direto do cliente;
-- >1 = update disparado por outro trigger (moderacao automatica confiavel).

create or replace function public.guard_profile_sensitive()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if auth.uid() is null or public.is_admin_user(auth.uid()) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.verification_status := 'unverified';
    new.account_status := 'active';
    new.profile_under_review := false;
    new.ufv_email := null;
    new.cpf_hash := null;
    new.created_at := now();
    return new;
  end if;

  new.verification_status := old.verification_status;
  new.account_status := old.account_status;
  new.profile_under_review := old.profile_under_review;
  new.ufv_email := old.ufv_email;
  new.cpf_hash := old.cpf_hash;
  new.birth_date := old.birth_date;
  new.created_at := old.created_at;
  new.updated_at := now();

  if new.avatar_url is distinct from old.avatar_url
     and new.avatar_url is not null
     and new.avatar_url not like auth.uid()::text || '/%' then
    raise exception 'caminho_invalido';
  end if;

  if new.photos is distinct from old.photos and new.photos is not null then
    if exists (
      select 1 from unnest(new.photos) x
      where x not like auth.uid()::text || '/%'
    ) then
      raise exception 'caminho_invalido';
    end if;
  end if;

  return new;
end;
$$;

-- @@

-- Restaura a conta de teste A (foi alterada pelo teste antes da correcao).
update public.profiles p
set account_status = 'active',
    profile_under_review = false,
    verification_status = 'verified',
    ufv_email = 'beta.reviewer@alunos.ufv.br'
from auth.users u
where u.id = p.id
  and lower(u.email) = 'beta.reviewer@alunos.ufv.br';
