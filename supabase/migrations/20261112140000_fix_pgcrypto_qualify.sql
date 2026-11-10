-- Bloco 2 (fix): pgcrypto vive no schema `extensions`; as funcoes de convite
-- foram criadas com search_path = public e chamavam gen_random_bytes/digest
-- sem qualificar, gerando 42883 em producao. Correcao, recriando as duas
-- funcoes com chamadas qualificadas (idempotente).

create or replace function public.create_group_invite(
  p_group_id uuid,
  p_expires_at timestamptz,
  p_max_uses int default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_hash text;
  v_id uuid;
begin
  if not public.has_group_permission(p_group_id, 'manage_invites', auth.uid()) then
    raise exception 'forbidden';
  end if;
  if p_max_uses < 1 or p_max_uses > 100 then raise exception 'usos_invalidos'; end if;
  if p_expires_at <= now() then raise exception 'validade_invalida'; end if;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');

  insert into public.group_invites (group_id, token_hash, expires_at, max_uses, created_by)
  values (p_group_id, v_hash, p_expires_at, p_max_uses, auth.uid())
  returning id into v_id;

  perform public.group_audit(
    p_group_id, 'create_invite', 'group_invites', v_id,
    jsonb_build_object('max_uses', p_max_uses, 'expires_at', p_expires_at)
  );

  return jsonb_build_object(
    'id', v_id,
    'token', v_token,
    'expires_at', p_expires_at,
    'max_uses', p_max_uses
  );
end;
$$;
grant execute on function public.create_group_invite(uuid, timestamptz, int) to authenticated;

-- @@

create or replace function public.redeem_group_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
  v_invite public.group_invites%rowtype;
  v_group uuid;
  v_role uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.is_verified_user(auth.uid()) then raise exception 'nao_verificado'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then raise exception 'diretrizes_necessarias'; end if;
  if p_token is null or length(p_token) = 0 then raise exception 'token invalido'; end if;

  v_hash := encode(extensions.digest(p_token, 'sha256'), 'hex');

  select * into v_invite
  from public.group_invites
  where token_hash = v_hash
  for update;

  if v_invite.id is null then raise exception 'convite invalido'; end if;
  if v_invite.revoked_at is not null then raise exception 'convite revogado'; end if;
  if v_invite.expires_at <= now() then raise exception 'convite expirado'; end if;
  if v_invite.used_count >= v_invite.max_uses then raise exception 'convite esgotado'; end if;

  v_group := v_invite.group_id;

  if exists (
    select 1 from public.group_members m
    where m.group_id = v_group and m.user_id = auth.uid() and m.status = 'active'
  ) then
    return v_group;
  end if;

  update public.group_invites set used_count = used_count + 1 where id = v_invite.id;

  insert into public.group_members (group_id, user_id, status, invited_by)
  values (v_group, auth.uid(), 'active', v_invite.created_by)
  on conflict (group_id, user_id)
  do update set status = 'active', updated_at = now();

  select r.id into v_role
  from public.group_roles r
  where r.group_id = v_group and lower(r.name) = 'membro' and not r.is_system
  order by r.rank
  limit 1;

  if v_role is not null then
    insert into public.group_member_roles (group_id, user_id, role_id)
    values (v_group, auth.uid(), v_role)
    on conflict (group_id, user_id, role_id) do nothing;
  end if;

  perform public.group_audit(
    v_group, 'redeem_invite', 'group_members', auth.uid(),
    jsonb_build_object('invite', v_invite.id)
  );

  return v_group;
end;
$$;
grant execute on function public.redeem_group_invite(text) to authenticated;
