-- Prepara as contas de teste (A/B) usadas nos testes de integracao:
-- verificadas, perfil completo e diretrizes aceitas.

do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('beta.reviewer@alunos.ufv.br', 'Revisor A'),
      ('beta.reviewer2@alunos.ufv.br', 'Revisor B')
    ) as t(email, display_name)
  loop
    update public.profiles p
    set verification_status = 'verified',
        display_name = coalesce(nullif(btrim(p.display_name), ''), r.display_name),
        course = coalesce(nullif(btrim(p.course), ''), 'Ciência da Computação'),
        campus = coalesce(nullif(btrim(p.campus), ''), 'Viçosa'),
        avatar_url = coalesce(nullif(btrim(p.avatar_url), ''), 'seed/test-avatar.png')
    from auth.users u
    where u.id = p.id and lower(u.email) = lower(r.email);

    insert into public.consents (user_id, type, version, accepted)
    select u.id, 'community_guidelines', '2026-11', true
    from auth.users u
    where lower(u.email) = lower(r.email)
      and not exists (
        select 1 from public.consents c
        where c.user_id = u.id and c.type = 'community_guidelines' and c.accepted = true
      );
  end loop;
end;
$$;
