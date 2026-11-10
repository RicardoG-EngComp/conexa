-- Normaliza campus/genero para aceitar acentos sem depender do encoding do cliente
create or replace function public.submit_beta_signup(
  p_name text default null,
  p_ufv_email text default null,
  p_gmail text default null,
  p_course text default null,
  p_campus text default null,
  p_gender text default null,
  p_how_heard text default null,
  p_difficulty text default null,
  p_website text default null,
  p_age boolean default false,
  p_android boolean default false,
  p_four_weeks boolean default false,
  p_consent_independent boolean default false,
  p_consent_firebase boolean default false,
  p_consent_privacy boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_ufv_email text := lower(btrim(coalesce(p_ufv_email, '')));
  v_gmail text := lower(btrim(coalesce(p_gmail, '')));
  v_course text := btrim(coalesce(p_course, ''));
  v_campus text := btrim(coalesce(p_campus, ''));
  v_gender text := btrim(coalesce(p_gender, ''));
  v_campus_key text;
  v_gender_key text;
  v_how_heard text := nullif(btrim(coalesce(p_how_heard, '')), '');
  v_difficulty text := nullif(btrim(coalesce(p_difficulty, '')), '');
  v_id uuid;
begin
  if nullif(btrim(coalesce(p_website, '')), '') is not null then
    return jsonb_build_object(
      'ok', true,
      'message', 'Inscricao recebida. A selecao considera a ordem de resposta e o equilibrio da amostra.'
    );
  end if;

  if v_name = '' or char_length(v_name) > 120 then
    return jsonb_build_object('ok', false, 'message', 'Informe seu nome completo.');
  end if;

  if v_ufv_email !~* '^[a-z0-9._%+\-]+@(alunos\.ufv\.br|ufv\.br)$' then
    return jsonb_build_object(
      'ok', false,
      'message', 'Use seu email institucional @alunos.ufv.br ou @ufv.br.'
    );
  end if;

  if v_gmail !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    return jsonb_build_object(
      'ok', false,
      'message', 'Informe uma conta Google valida para o Firebase.'
    );
  end if;

  if v_course = '' or char_length(v_course) > 160 then
    return jsonb_build_object('ok', false, 'message', 'Selecione seu curso.');
  end if;

  v_campus_key := translate(
    lower(v_campus),
    U&'\00E1\00E0\00E2\00E3\00E4\00E9\00E8\00EA\00EB\00ED\00EC\00EE\00EF\00F3\00F2\00F4\00F5\00F6\00FA\00F9\00FB\00FC\00E7',
    'aaaaaeeeeiiiiooooouuuuc'
  );

  if v_campus_key not in ('vicosa', 'florestal', 'rio paranaiba') then
    return jsonb_build_object('ok', false, 'message', 'Selecione um campus valido.');
  end if;

  v_gender_key := translate(
    lower(v_gender),
    U&'\00E1\00E0\00E2\00E3\00E4\00E9\00E8\00EA\00EB\00ED\00EC\00EE\00EF\00F3\00F2\00F4\00F5\00F6\00FA\00F9\00FB\00FC\00E7',
    'aaaaaeeeeiiiiooooouuuuc'
  );

  if v_gender_key not in (
    'mulher cis',
    'mulher trans',
    'homem cis',
    'homem trans',
    'pessoa nao binaria',
    'outro',
    'prefiro nao informar'
  ) then
    return jsonb_build_object('ok', false, 'message', 'Selecione como voce se identifica.');
  end if;

  if not coalesce(p_age, false)
     or not coalesce(p_android, false)
     or not coalesce(p_four_weeks, false) then
    return jsonb_build_object(
      'ok', false,
      'message', 'Confirme os requisitos do beta.'
    );
  end if;

  if not coalesce(p_consent_independent, false)
     or not coalesce(p_consent_firebase, false)
     or not coalesce(p_consent_privacy, false) then
    return jsonb_build_object(
      'ok', false,
      'message', 'Aceite os consentimentos para continuar.'
    );
  end if;

  if (v_how_heard is not null and char_length(v_how_heard) > 500)
     or (v_difficulty is not null and char_length(v_difficulty) > 500) then
    return jsonb_build_object('ok', false, 'message', 'Texto muito longo.');
  end if;

  begin
    insert into public.beta_signups (
      name,
      ufv_email,
      gmail,
      course,
      campus,
      gender,
      how_heard,
      difficulty,
      age_confirmed,
      android,
      four_weeks,
      consent_independent,
      consent_firebase,
      consent_privacy,
      source
    ) values (
      v_name,
      v_ufv_email,
      v_gmail,
      v_course,
      v_campus,
      v_gender,
      v_how_heard,
      v_difficulty,
      true,
      true,
      true,
      true,
      true,
      true,
      'beta-site'
    )
    returning id into v_id;
  exception when unique_violation then
    return jsonb_build_object(
      'ok', false,
      'code', 'duplicate',
      'message', 'Inscricao ja recebida para este email UFV ou conta Google.'
    );
  end;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'message', 'Inscricao recebida. A selecao considera a ordem de resposta e o equilibrio da amostra.'
  );
end;
$$;

grant execute on function public.submit_beta_signup(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean
) to anon, authenticated;

notify pgrst, 'reload schema';
