-- P0 fix: consents usa accepted_at, nao created_at.

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(v_uid) then raise exception 'conta_inativa'; end if;

  return jsonb_build_object(
    'exported_at', now(),
    'account', (
      select jsonb_build_object(
        'email', u.email,
        'created_at', u.created_at,
        'last_sign_in_at', u.last_sign_in_at
      )
      from auth.users u where u.id = v_uid
    ),
    'profile', (
      select to_jsonb(p) - 'cpf_hash'
      from public.profiles p where p.id = v_uid
    ),
    'posts', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.posts x where x.user_id = v_uid
    ), '[]'::jsonb),
    'comments', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.comments x where x.user_id = v_uid
    ), '[]'::jsonb),
    'likes', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.likes x where x.user_id = v_uid
    ), '[]'::jsonb),
    'connections', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.connections x
      where x.requester_id = v_uid or x.addressee_id = v_uid
    ), '[]'::jsonb),
    'blocks', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.blocks x where x.blocker_id = v_uid
    ), '[]'::jsonb),
    'mutes', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.user_mutes x where x.muter_id = v_uid
    ), '[]'::jsonb),
    'muted_words', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.muted_words x where x.user_id = v_uid
    ), '[]'::jsonb),
    'conversations', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.conversations x
      where exists (
        select 1 from public.conversation_participants p
        where p.conversation_id = x.id and p.user_id = v_uid
      )
    ), '[]'::jsonb),
    'messages', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.messages x
      where exists (
        select 1 from public.conversation_participants p
        where p.conversation_id = x.conversation_id and p.user_id = v_uid
      )
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.reports x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'consents', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.accepted_at)
      from public.consents x where x.user_id = v_uid
    ), '[]'::jsonb),
    'badges', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.user_badges x where x.user_id = v_uid
    ), '[]'::jsonb),
    'study_materials', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.study_materials x where x.author_id = v_uid
    ), '[]'::jsonb),
    'study_votes', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.study_material_votes x where x.user_id = v_uid
    ), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_members x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_roles', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_member_roles x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_follows', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_followers x where x.user_id = v_uid
    ), '[]'::jsonb),
    'group_invites', coalesce((
      select jsonb_agg(to_jsonb(x))
      from public.group_invites x
      where x.target_user_id = v_uid or x.created_by = v_uid
    ), '[]'::jsonb),
    'bug_reports', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.bug_reports x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'suggestions', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.suggestions x where x.reporter_id = v_uid
    ), '[]'::jsonb),
    'notifications', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at)
      from public.notifications x where x.user_id = v_uid
    ), '[]'::jsonb),
    'notification_preferences', (
      select to_jsonb(x)
      from public.notification_preferences x where x.user_id = v_uid
    ),
    'devices', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.last_seen_at desc)
      from public.user_devices x where x.user_id = v_uid
    ), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.export_my_data() to authenticated;
