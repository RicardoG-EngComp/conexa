-- Moderacao, denuncias e preparacao para a Play Store

create or replace function public.is_admin_user(uid uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.admins a where a.user_id = uid);
$$;
grant execute on function public.is_admin_user(uuid) to authenticated;

-- @@

create or replace function public.is_active_user(uid uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = uid and p.account_status = 'active'
  );
$$;
grant execute on function public.is_active_user(uuid) to authenticated;

-- @@

create or replace function public.has_accepted_guidelines(uid uuid default auth.uid())
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.consents c
    where c.user_id = uid
      and c.type = 'community_guidelines'
      and c.accepted = true
  );
$$;
grant execute on function public.has_accepted_guidelines(uuid) to authenticated;

-- @@

create table if not exists public.moderation_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  content_type text not null,
  content_id uuid,
  category text not null,
  snippet text,
  action text not null default 'blocked',
  created_at timestamptz not null default now()
);

alter table public.moderation_events enable row level security;

drop policy if exists "moderation_events_select_admin" on public.moderation_events;
create policy "moderation_events_select_admin" on public.moderation_events
  for select to authenticated
  using (public.is_admin_user(auth.uid()));

-- @@

create or replace function public.content_policy_category(p_content text)
returns text
language plpgsql
immutable
as $$
declare
  c text;
begin
  if p_content is null or btrim(p_content) = '' then
    return null;
  end if;

  c := lower(p_content);
  c := translate(
    c,
    'áàâãäéèêëíìîïóòôõöúùûüçñ',
    'aaaaaeeeeiiiiooooouuuucn'
  );

  if c ~ '\m(viado|bicha|traveco|retardado|mongoloide|preto imundo|preta imunda|macaco imundo)\M' then
    return 'intolerancia_discriminacao';
  end if;

  if c ~ '\m(vou te matar|vou te bater|vou te estuprar|vou acabar com voce|sei onde voce mora|vou te pegar|vou te encontrar|matar todos)\M' then
    return 'violencia_ameaca';
  end if;

  if c ~ '\m(manda nude|manda nudes|manda foto pelada|manda foto sem roupa|quero ver seu corpo|video de sexo|pornografia|porno|onlyfans|xvideo)\M' then
    return 'conteudo_sexual_explicito';
  end if;

  if c ~ '\m(vagabunda|vadia|piranha|otaria|lixo humano|nojenta|nojento)\M' then
    return 'assedio';
  end if;

  return null;
end;
$$;

-- @@

create or replace function public.enforce_content_policy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_text text := '';
  v_category text;
begin
  if tg_table_name = 'profiles' then
    v_text := coalesce(new.display_name, '') || ' ' ||
              coalesce(new.bio, '') || ' ' ||
              coalesce(new.prompts::text, '');
  elsif tg_table_name = 'conversations' then
    v_text := coalesce(new.request_message, '');
  else
    v_text := coalesce(new.content, '');
  end if;

  v_category := public.content_policy_category(v_text);
  if v_category is not null then
    insert into public.moderation_events
      (user_id, content_type, content_id, category, snippet, action)
    values
      (auth.uid(), tg_table_name, new.id, v_category, left(v_text, 200), 'blocked');
    raise exception 'conteudo_proibido:%', v_category;
  end if;

  return new;
end;
$$;

-- @@

drop trigger if exists posts_content_policy on public.posts;
create trigger posts_content_policy
before insert or update of content on public.posts
for each row execute function public.enforce_content_policy();

drop trigger if exists comments_content_policy on public.comments;
create trigger comments_content_policy
before insert or update of content on public.comments
for each row execute function public.enforce_content_policy();

drop trigger if exists messages_content_policy on public.messages;
create trigger messages_content_policy
before insert or update of content on public.messages
for each row execute function public.enforce_content_policy();

drop trigger if exists profiles_content_policy on public.profiles;
create trigger profiles_content_policy
before insert or update of display_name, bio, prompts on public.profiles
for each row execute function public.enforce_content_policy();

drop trigger if exists conversations_content_policy on public.conversations;
create trigger conversations_content_policy
before insert or update of request_message on public.conversations
for each row execute function public.enforce_content_policy();

-- @@

create or replace function public.enforce_active_guidelines()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if not public.is_active_user(auth.uid()) then
    raise exception 'conta_inativa';
  end if;
  if not public.has_accepted_guidelines(auth.uid()) then
    raise exception 'diretrizes_necessarias';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_active_guidelines on public.posts;
create trigger posts_active_guidelines
before insert on public.posts
for each row execute function public.enforce_active_guidelines();

drop trigger if exists comments_active_guidelines on public.comments;
create trigger comments_active_guidelines
before insert on public.comments
for each row execute function public.enforce_active_guidelines();

drop trigger if exists messages_active_guidelines on public.messages;
create trigger messages_active_guidelines
before insert on public.messages
for each row execute function public.enforce_active_guidelines();

drop trigger if exists connections_active_guidelines on public.connections;
create trigger connections_active_guidelines
before insert on public.connections
for each row execute function public.enforce_active_guidelines();

drop trigger if exists conversations_active_guidelines on public.conversations;
create trigger conversations_active_guidelines
before insert on public.conversations
for each row execute function public.enforce_active_guidelines();

-- @@

alter table public.posts add column if not exists hidden_at timestamptz;
alter table public.comments add column if not exists hidden_at timestamptz;
alter table public.messages add column if not exists hidden_at timestamptz;
alter table public.profiles add column if not exists profile_under_review boolean not null default false;

-- @@

create or replace function public.can_view_post(post_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.posts po
    join public.profiles pr on pr.id = po.user_id
    where po.id = post_id
      and po.hidden_at is null
      and pr.account_status = 'active'
      and not public.is_blocked(auth.uid(), po.user_id)
      and (
        po.user_id = auth.uid()
        or (pr.profile_private = false and po.visibility = 'public')
        or public.is_connection(auth.uid(), po.user_id)
      )
  );
$$;

-- @@

drop view if exists public.profiles_public;
create view public.profiles_public as
  select p.id, p.display_name, p.course, p.campus, p.bio, p.prompts,
         p.avatar_url, p.photos, p.interests, p.relationship_style,
         p.verification_status, p.profile_private, p.created_at
  from public.profiles p
  where p.account_status = 'active'
    and p.profile_under_review = false
    and not exists (
      select 1 from public.blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = auth.uid())
    );

alter view public.profiles_public set (security_invoker = false);
grant select on public.profiles_public to authenticated;

-- @@

create or replace function public.discover_profiles(
  p_limit int default 30,
  p_offset int default 0,
  p_course text default null,
  p_search text default null
)
returns table (
  id uuid,
  display_name text,
  course text,
  campus text,
  avatar_url text,
  verification_status text
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, p.display_name, p.course, p.campus, p.avatar_url,
         p.verification_status
  from public.profiles p
  where p.id <> auth.uid()
    and p.account_status = 'active'
    and p.profile_under_review = false
    and p.display_name is not null and length(btrim(p.display_name)) > 0
    and p.course is not null and length(btrim(p.course)) > 0
    and p.campus is not null and length(btrim(p.campus)) > 0
    and p.avatar_url is not null and length(btrim(p.avatar_url)) > 0
    and (p_course is null or p.course = p_course)
    and (
      p_search is null or btrim(p_search) = ''
      or p.display_name ilike '%' || p_search || '%'
      or p.course ilike '%' || p_search || '%'
    )
    and not public.is_blocked(auth.uid(), p.id)
  order by p.created_at desc
  limit greatest(p_limit, 0) offset greatest(p_offset, 0);
$$;

grant execute on function public.discover_profiles(int, int, text, text) to authenticated;

-- @@

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select to authenticated
  using (
    public.is_conversation_participant(conversation_id)
    and hidden_at is null
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
  );

drop policy if exists "messages_insert_participant" on public.messages;
create policy "messages_insert_participant" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_active_user(auth.uid())
    and public.has_accepted_guidelines(auth.uid())
    and public.is_conversation_participant(conversation_id)
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and c.status = 'accepted'
    )
    and not public.conversation_has_block(conversation_id)
  );

-- @@

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own" on public.posts
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.is_active_user(auth.uid())
    and public.has_accepted_guidelines(auth.uid())
    and public.is_profile_complete(auth.uid())
  );

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own" on public.comments
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and public.is_active_user(auth.uid())
    and public.has_accepted_guidelines(auth.uid())
    and public.is_profile_complete(auth.uid())
    and public.can_view_post(post_id)
  );

-- @@

create or replace function public.handle_report_autohide()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  severe boolean;
begin
  severe := new.category in (
    'intolerancia_discriminacao',
    'violencia_ameaca',
    'conteudo_sexual_explicito',
    'imagem_nao_consentida',
    'menor_de_idade'
  );

  if not severe then
    return new;
  end if;

  if new.target_type = 'post' and new.target_id is not null then
    update public.posts set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'comment' and new.target_id is not null then
    update public.comments set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'message' and new.target_id is not null then
    update public.messages set hidden_at = now()
    where id = new.target_id and hidden_at is null;
  elsif new.target_type = 'profile' then
    update public.profiles set profile_under_review = true
    where id = new.reported_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists reports_autohide on public.reports;
create trigger reports_autohide
after insert on public.reports
for each row execute function public.handle_report_autohide();

-- @@

create or replace function public.admin_moderate_content(
  p_target_type text,
  p_target_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  if p_action = 'hide' then
    if p_target_type = 'post' then
      update public.posts set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'message' then
      update public.messages set hidden_at = now() where id = p_target_id;
    elsif p_target_type = 'profile' then
      update public.profiles set profile_under_review = true where id = p_target_id;
    end if;
  elsif p_action = 'restore' then
    if p_target_type = 'post' then
      update public.posts set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'comment' then
      update public.comments set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'message' then
      update public.messages set hidden_at = null where id = p_target_id;
    elsif p_target_type = 'profile' then
      update public.profiles set profile_under_review = false where id = p_target_id;
    end if;
  elsif p_action = 'delete' then
    if p_target_type = 'post' then
      delete from public.posts where id = p_target_id;
    elsif p_target_type = 'comment' then
      delete from public.comments where id = p_target_id;
    elsif p_target_type = 'message' then
      delete from public.messages where id = p_target_id;
    end if;
  else
    raise exception 'invalid action';
  end if;

  insert into public.audit_log (actor_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    p_action,
    null,
    jsonb_build_object('target_type', p_target_type, 'target_id', p_target_id)
  );
end;
$$;

grant execute on function public.admin_moderate_content(text, uuid, text) to authenticated;

-- @@

-- Beta: upload de pacotes de figurinhas por usuario desabilitado
drop policy if exists "sticker_packs_insert_own" on public.sticker_packs;
drop policy if exists "sticker_packs_insert_admin" on public.sticker_packs;
create policy "sticker_packs_insert_admin" on public.sticker_packs
  for insert to authenticated
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "stickers_insert_own" on public.stickers;
drop policy if exists "stickers_insert_admin" on public.stickers;
create policy "stickers_insert_admin" on public.stickers
  for insert to authenticated
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "stickers_media_insert_own" on storage.objects;
drop policy if exists "stickers_media_update_own" on storage.objects;
