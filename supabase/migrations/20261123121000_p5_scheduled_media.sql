-- P5: agendamento com midia (imagens) e indice de GC.

create index if not exists media_objects_scope_created_idx
  on public.media_objects (scope, created_at)
  where deleted_at is null;

create or replace function public.schedule_post(
  p_payload jsonb,
  p_scheduled_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content text := btrim(coalesce(p_payload->>'content', ''));
  v_pending int;
  v_media jsonb := coalesce(p_payload->'media', '[]'::jsonb);
  v_item jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_active_user(auth.uid()) then raise exception 'conta_inativa'; end if;
  if not public.has_accepted_guidelines(auth.uid()) then
    raise exception 'diretrizes_necessarias';
  end if;
  if char_length(v_content) < 1 or char_length(v_content) > 2000 then
    raise exception 'conteudo_invalido';
  end if;
  if p_scheduled_at < now() + interval '5 minutes'
     or p_scheduled_at > now() + interval '30 days' then
    raise exception 'data_invalida';
  end if;
  if jsonb_array_length(v_media) > 4 then raise exception 'maximo_midias'; end if;

  for v_item in select value from jsonb_array_elements(v_media)
  loop
    if v_item->>'kind' is distinct from 'image' then
      raise exception 'midia_invalida';
    end if;
    if (v_item->>'path') is null
       or (v_item->>'path') not like auth.uid()::text || '/feed/%' then
      raise exception 'midia_invalida';
    end if;
  end loop;

  select count(*) into v_pending
  from public.scheduled_posts
  where user_id = auth.uid() and status = 'pending';
  if v_pending >= 10 then raise exception 'limite_agendamentos'; end if;

  insert into public.scheduled_posts (user_id, payload, scheduled_at)
  values (auth.uid(), p_payload, p_scheduled_at);

  return jsonb_build_object('scheduled_at', p_scheduled_at);
end;
$$;
grant execute on function public.schedule_post(jsonb, timestamptz) to authenticated;

create or replace function public.publish_due_scheduled_posts()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.scheduled_posts%rowtype;
  v_content text;
  v_visibility text;
  v_reply_policy text;
  v_post_id uuid;
  v_topic uuid;
  v_mention uuid;
  v_media jsonb;
  v_item jsonb;
  v_option text;
  v_pos int;
  v_poll_id uuid;
  v_count int;
  v_published int := 0;
  v_failed int := 0;
begin
  for v_row in
    select * from public.scheduled_posts
    where status = 'pending' and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    begin
      if not public.is_active_user(v_row.user_id)
         or not public.has_accepted_guidelines(v_row.user_id) then
        raise exception 'conta_indisponivel';
      end if;

      perform set_config('request.jwt.claim.sub', v_row.user_id::text, true);
      perform set_config(
        'request.jwt.claims',
        jsonb_build_object('sub', v_row.user_id::text)::text,
        true
      );

      v_content := btrim(coalesce(v_row.payload->>'content', ''));
      v_visibility := coalesce(v_row.payload->>'visibility', 'public');
      v_reply_policy := coalesce(v_row.payload->>'reply_policy', 'anyone');
      v_media := coalesce(v_row.payload->'media', '[]'::jsonb);

      if char_length(v_content) < 1 or char_length(v_content) > 2000 then
        raise exception 'conteudo_invalido';
      end if;
      if v_visibility not in ('public', 'friends') then
        raise exception 'visibilidade_invalida';
      end if;
      if v_reply_policy not in ('anyone', 'connections') then
        raise exception 'resposta_invalida';
      end if;
      if public.content_policy_category(v_content) is not null then
        raise exception 'conteudo_proibido';
      end if;
      if jsonb_array_length(v_media) > 4 then raise exception 'maximo_midias'; end if;

      v_post_id := gen_random_uuid();
      insert into public.posts (
        id, user_id, content, visibility, reply_policy, posted_as_group
      ) values (
        v_post_id, v_row.user_id, v_content, v_visibility, v_reply_policy, false
      );

      for v_topic in
        select value::uuid
        from jsonb_array_elements_text(
          coalesce(v_row.payload->'topic_ids', '[]'::jsonb)
        )
        limit 5
      loop
        insert into public.post_topics (post_id, topic_id)
        values (v_post_id, v_topic)
        on conflict do nothing;
      end loop;

      for v_mention in
        select value::uuid
        from jsonb_array_elements_text(
          coalesce(v_row.payload->'mentions', '[]'::jsonb)
        )
        limit 10
      loop
        if v_mention <> v_row.user_id
           and public.is_active_user(v_mention)
           and not public.is_blocked(v_row.user_id, v_mention) then
          insert into public.post_mentions (post_id, user_id, mentioned_by)
          values (v_post_id, v_mention, v_row.user_id)
          on conflict do nothing;
        end if;
      end loop;

      for v_item in select value from jsonb_array_elements(v_media)
      loop
        if v_item->>'kind' = 'image' then
          insert into public.post_media (
            post_id, owner_id, object_key, kind, mime_type, byte_size,
            width, height, alt_text, position
          ) values (
            v_post_id,
            v_row.user_id,
            v_item->>'path',
            'image',
            v_item->>'mime_type',
            (v_item->>'byte_size')::bigint,
            (v_item->>'width')::int,
            (v_item->>'height')::int,
            v_item->>'alt_text',
            coalesce((v_item->>'position')::int, 0)
          );
        end if;
      end loop;

      if v_row.payload->'poll' is not null then
        select count(*) into v_count
        from jsonb_array_elements(v_row.payload->'poll'->'options');
        if v_count between 2 and 4 then
          insert into public.polls (post_id, expires_at)
          values (
            v_post_id,
            now() + make_interval(
              hours => greatest(
                1,
                least(168, coalesce((v_row.payload->'poll'->>'hours')::int, 24))
              )
            )
          )
          returning id into v_poll_id;

          v_pos := 0;
          for v_option in
            select value
            from jsonb_array_elements_text(v_row.payload->'poll'->'options')
          loop
            if char_length(btrim(v_option)) between 1 and 80 then
              insert into public.poll_options (poll_id, label, position)
              values (v_poll_id, btrim(v_option), v_pos);
            end if;
            v_pos := v_pos + 1;
          end loop;
        end if;
      end if;

      update public.scheduled_posts
      set status = 'published', post_id = v_post_id, updated_at = now()
      where id = v_row.id;
      v_published := v_published + 1;
    exception when others then
      update public.scheduled_posts
      set status = 'failed', error = sqlerrm, updated_at = now()
      where id = v_row.id;
      v_failed := v_failed + 1;
    end;
  end loop;

  return jsonb_build_object('published', v_published, 'failed', v_failed);
end;
$$;

revoke all on function public.publish_due_scheduled_posts()
  from public, anon, authenticated;
grant execute on function public.publish_due_scheduled_posts() to service_role;
