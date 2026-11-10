-- Bloco 7: moderacao de conteudo por moderadores de grupo.

create or replace function public.group_moderate_post(
  p_post_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select po.group_id into v_group from public.posts po where po.id = p_post_id;
  if v_group is null then raise exception 'post_de_grupo_necessario'; end if;
  if not public.has_group_permission(v_group, 'moderate_content', auth.uid()) then
    raise exception 'forbidden';
  end if;

  if p_action = 'hide' then
    update public.posts set hidden_at = now()
    where id = p_post_id and hidden_at is null;
  elsif p_action = 'restore' then
    update public.posts set hidden_at = null where id = p_post_id;
  elsif p_action = 'delete' then
    delete from public.posts where id = p_post_id;
  else
    raise exception 'acao invalida';
  end if;

  perform public.group_audit(v_group, 'moderate_post_' || p_action, 'posts', p_post_id);
end;
$$;
grant execute on function public.group_moderate_post(uuid, text) to authenticated;

-- @@

create or replace function public.group_moderate_comment(
  p_comment_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select po.group_id into v_group
  from public.comments c
  join public.posts po on po.id = c.post_id
  where c.id = p_comment_id;

  if v_group is null then raise exception 'comentario_de_grupo_necessario'; end if;
  if not public.has_group_permission(v_group, 'moderate_content', auth.uid()) then
    raise exception 'forbidden';
  end if;

  if p_action = 'hide' then
    update public.comments set hidden_at = now()
    where id = p_comment_id and hidden_at is null;
  elsif p_action = 'restore' then
    update public.comments set hidden_at = null where id = p_comment_id;
  elsif p_action = 'delete' then
    delete from public.comments where id = p_comment_id;
  else
    raise exception 'acao invalida';
  end if;

  perform public.group_audit(v_group, 'moderate_comment_' || p_action, 'comments', p_comment_id);
end;
$$;
grant execute on function public.group_moderate_comment(uuid, text) to authenticated;

-- @@
-- Comentarios ocultos nao podem ser lidos (correcao de vazamento).

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select to authenticated
  using (public.can_view_post(post_id) and hidden_at is null);
