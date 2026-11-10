-- Bloco 3 (respostas e citacoes): comentarios encadeados (ate 3 niveis)
-- e republicacao com comentario (citacao) com protecao contra vazamento.

alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade,
  add column if not exists depth int not null default 0;

alter table public.comments
  drop constraint if exists comments_depth_check;
alter table public.comments
  add constraint comments_depth_check check (depth between 0 and 3);

create index if not exists comments_parent_idx on public.comments (parent_id);
create index if not exists comments_post_created_idx
  on public.comments (post_id, created_at);

create or replace function public.set_comment_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent public.comments%rowtype;
begin
  if new.parent_id is null then
    new.depth := 0;
    return new;
  end if;

  select * into v_parent from public.comments where id = new.parent_id;
  if v_parent.id is null then raise exception 'comentario_pai_inexistente'; end if;
  if v_parent.post_id <> new.post_id then raise exception 'comentario_de_outro_post'; end if;
  if v_parent.depth >= 3 then raise exception 'profundidade_maxima'; end if;

  new.depth := v_parent.depth + 1;
  return new;
end;
$$;

drop trigger if exists comments_set_thread on public.comments;
create trigger comments_set_thread
before insert on public.comments
for each row execute function public.set_comment_thread();

-- @@

alter table public.posts
  add column if not exists quoted_post_id uuid references public.posts(id) on delete set null,
  add column if not exists was_quote boolean not null default false;

alter table public.posts
  drop constraint if exists posts_no_self_quote;
alter table public.posts
  add constraint posts_no_self_quote
  check (quoted_post_id is null or quoted_post_id <> id);

create index if not exists posts_quoted_idx on public.posts (quoted_post_id);

create or replace function public.enforce_post_quote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.quoted_post_id is null then
    new.was_quote := false;
    return new;
  end if;

  if not public.can_view_post(new.quoted_post_id) then
    raise exception 'publicacao_inacessivel';
  end if;

  new.was_quote := true;
  return new;
end;
$$;

drop trigger if exists posts_quote_enforce on public.posts;
create trigger posts_quote_enforce
before insert on public.posts
for each row execute function public.enforce_post_quote();
