# Grupos e Feed — regras da versão 1.0.14

> Documento interno de referência. Descreve as regras que valem no servidor
> (RLS, triggers e RPCs), não apenas na interface.
>
> Para o histórico completo e a lista do que **não pode ser alterado**, consulte
> [`BACKEND-INVARIANTES.md`](BACKEND-INVARIANTES.md).

## Princípio

Segurança aplicada no servidor: grupos privados invisíveis, convite como
segredo, cargo registrado com snapshot, citação sem cópia de conteúdo e
moderação por contexto de grupo. A interface apenas esconde o que o servidor
já bloqueia.

---

## 1. Feed

### Estrutura

- **para você**: posts públicos — posts pessoais de perfis públicos e posts de
  grupos públicos aprovados. Janela: últimos 30 dias.
- **conexão**: posts próprios + posts de conexões aceitas (público ou somente
  conexões) + posts de grupos públicos que você segue.
- Bloqueio de autor, perfil oculto/banido e conteúdo oculto (`hidden_at`)
  excluídos das duas abas.
- Sem ranking opaco: o critério é fixo, documentado e visível na interface
  (chips "Seu curso", "Seu campus").

### Fórmula de relevância (para você)

| Critério | Pontos |
|---|---|
| Curso do post igual ao curso do perfil | +3 |
| Campus do post igual ao campus do perfil | +2 |
| Categoria de evento presente nos interesses | +2 |
| Publicado nas últimas 24 horas | +1 |
| Publicado nos últimos 7 dias | +1 |

Desempate: `created_at` descendente e depois `id`.

### Tipos estruturados (`topics` + `post_topics`)

- **curso** (máx. 1 por post): seed com os cursos da UFV.
- **campus** (máx. 1 por post): Viçosa, Florestal, Rio Paranaíba.
- **categoria de evento** (máx. 3 por post): acadêmico, cultural, esportivo,
  festa, carreira, extensão, social, outro.
- Total por post: até 5 tópicos. Validado por trigger no servidor.

RPCs: `feed_for_you(limit, offset)` e `feed_connections(limit, offset)`
retornam ids ordenados + origem/flags de relevância; o app busca os detalhes
passando pela RLS.

---

## 2. Grupos

### Visibilidade e selo

- **privado**: visível apenas para membros; não aparece na busca nem em
  diretório; entrada somente por convite.
- **público**: exige **aprovação manual** da moderação (`admin_review_group`);
  aprovado recebe **selo oficial** (`is_official`). Entrada aberta para
  contas verificadas com diretrizes aceitas.
  Estados: `public_approval = pending -> approved | rejected`.
- Nome:
  - público: **único e normalizado** (minúsculas, sem acento, espaços
    colapsados) via índice parcial;
  - privado: nomes repetíveis permitidos, sujeitos à moderação de conteúdo.
- Grupo em revisão (`under_review`) ou arquivado sai do diretório; membros
  continuam vendo.

### Categorias

Categorias oficiais de grupo (fixas, validadas no servidor):

`Centro Acadêmico`, `Atlética`, `Grupo de Estudos`, `República`, `Outros`.

Valores fora dessa lista são rejeitados com `categoria_invalida`; dados antigos
foram normalizados (maiúsculas/acentos reconhecidos; o resto virou `Outros`).

### Cargos e permissões

Cargos são combináveis; as permissões de todos os cargos do membro somam.

| Permissão | Chave no banco |
|---|---|
| Gerenciar grupo | `manage_group` |
| Gerenciar cargos | `manage_roles` |
| Gerenciar membros | `manage_members` |
| Gerenciar convites | `manage_invites` |
| Publicar em nome do grupo | `post_as_group` |
| Moderar conteúdo | `moderate_content` |

Regras fixas no servidor:

- Cargo do **dono** (`is_system`) tem todas as permissões, não pode ser
  editado, apagado nem atribuído/removido.
- **Ninguém se atribui cargo** (`assign_group_role` bloqueia
  `p_user_id = auth.uid()`).
- Só quem tem `manage_roles` cria/edita/apaga/atribui cargos.
- Cargos só podem ser atribuídos a membros ativos do próprio grupo.

### Publicação no grupo e selo

- Post de grupo exige **cargo**: registra `group_id`, autor (membro ativo),
  `role_id` e `role_name_snapshot` gravado no momento da publicação.
- "Publicar em nome do grupo" (`posted_as_group`) exige `post_as_group`;
  o post aparece com nome/selo do grupo, sempre mostrando o membro autor.
- **Selo em post pessoal** só com cargo de grupo **público verificado**
  (`selo_exige_grupo_publico`); o selo não altera quem vê o post.
- **Cargo à época**: post guarda o snapshot. Se o cargo for retirado ou
  apagado, `role_id` passa a nulo mas o snapshot continua; a interface exibe
  "cargo à época".

### Convites

Convites são **100% dentro do app** — não existe link, código ou cópia:

- `create_group_invite_for_user(group_id, target_user_id)` — exige
  `manage_invites`, valida que o convidado é uma **conexão aceita**
  (`is_connection`), cria convite de **1 uso** (validade 7 dias) e envia
  **notificação in-app** (`group_invite`, rota `/invites`).
- O convidado vê o convite em **Grupos → Convites recebidos**
  (`my_group_invites`) e pode **Entrar** (`accept_group_invite`) ou
  **Recusar** (`decline_group_invite`). O aceite valida: destinatário correto,
  não revogado/expirado/esgotado, conta ativa, verificada e diretrizes aceitas.
- `revoke_group_invite` anula o convite imediatamente.
- Convites antigos por link aparecem como “legado” apenas para revogação;
  nenhuma rota de link é exposta pelo app.

### Membros e seguidores

- `remove_group_member` retira o membro (não remove o dono).
- `remove_group_follower(group_id, user_id)` retira um seguidor; ambos exigem
  `manage_members` e ficam registrados na auditoria do grupo.
- O dono pode **excluir o grupo** (`delete_group`), com cascata em membros,
  cargos, convites, seguidores, publicações do grupo e auditoria.

### Moderação dentro do grupo

- `group_moderate_post(post_id, action)` e
  `group_moderate_comment(comment_id, action)`, ações `hide`/`restore`/`delete`,
  exigem `moderate_content` **no grupo do conteúdo**.
- Conteúdo oculto não é legível por ninguém (a RLS de posts e comentários
  filtra `hidden_at`); restaurar conteúdo oculto é papel do painel admin
  (`admin_moderate_content`).
- Ações de admin (`admin_moderate_content`) continuam válidas para posts e
  comentários de grupo.

### Denúncia

- Denúncias de post/comentário de grupo usam os mesmos alvos (`post`,
  `comment`) e a ocultação automática de categorias graves já cobre grupos.
- O menu do cartão continua oferecendo "Denunciar"; moderadores do grupo
  veêm ainda "Ocultar"/"Apagar".

### Interações em posts de grupo

- **Respostas**: encadeadas até 3 níveis (`comments.parent_id`/`depth`,
  trigger valida mesmo post e limite; 4º nível é rejeitado).
- **Citação** ("republicar com comentário"): `posts.quoted_post_id` guarda só
  a referência. Na criação, o servidor exige `can_view_post` do citado;
  na leitura, a prévia é buscada em tempo real pela RLS. Post citado
  inacessível (bloqueado, privado, oculto ou removido) aparece como
  "Conteúdo indisponível", sem autor nem texto.
- **Bloqueios**: `can_view_post` bloqueia o autor real, inclusive quando o
  post é publicado em nome do grupo.

### Auditoria

- `group_audit_events`: quem criou/editou/atribuiu/revogou/moderou cada
  registro do grupo, visível a quem tem `manage_group` e aos admins.
- Ações de admin também gravam em `audit_log`.

---

## 3. Segurança no servidor (resumo de RLS)

| Regra | Onde vale |
|---|---|
| Grupo privado invisível para não membros e na busca | `can_view_group` + política de select de `groups` |
| Posts de grupo só via contexto do grupo | `can_view_post` ignora visibilidade pessoal quando `group_id` não nulo |
| Post de grupo exige membro ativo, cargo atribuído e permissões | trigger `posts_role_enforce` |
| Comentar/citar exige poder ver o post | políticas com `can_view_post` + trigger `enforce_post_quote` |
| Comentário oculto ilegível | `comments_select_auth` com `hidden_at is null` |
| Convite não expõe token | `group_invites` guarda hash; select restrito a gestores |
| Cargo no perfil só de grupo público verificado | `set_role_profile_visibility` |

---

## 4. Migrations desta versão

| Migration | Conteúdo |
|---|---|
| `20261109120000_groups_core.sql` | tabelas de grupo + nome normalizado |
| `20261109121000_groups_security.sql` | permissões, RLS e RPCs de grupo/convite |
| `20261109130000_seed_test_accounts.sql` | contas de teste A/B prontas |
| `20261109140000_feed_topics.sql` | tópicos, `posts.group_id`, feeds |
| `20261109150000_feed_replies_quotes.sql` | respostas encadeadas e citações |
| `20261109160000_posts_group_role.sql` | cargo/snapshot em posts |
| `20261109170000_group_directory.sql` | `group_stats` e diretório público |
| `20261109171000_remove_group_member.sql` | remover membro |
| `20261109180000_group_moderation.sql` | moderação de grupo + correção de comentário oculto |

---

## 5. Checklist de RLS antes de liberar

Testes de integração (executar com credenciais reais):

| Arquivo | Cobre |
|---|---|
| `test/integration/groups_rls_test.dart` | grupo privado invisível; nome público único repetindo acentos/caixa/espaços; convite válido, revogado e vencido; auto-atribuição e cargo do dono bloqueados |
| `test/integration/replies_quotes_test.dart` | limite de 3 níveis de resposta; citação de post inacessível bloqueada; citação mantém `was_quote` se o original for apagado |
| `test/integration/posts_group_role_test.dart` | membro publica com cargo; só gestor publica em nome; cargo de outro grupo rejeitado; selo pessoal exige grupo público; snapshot permanece após remover/apagar cargo |
| `test/integration/group_moderation_test.dart` | moderador oculta post e resposta, não-moderador falha; post de grupo privado fora do feed de não membro; citação/resposta respeitam o grupo; bloqueio vale em post de grupo |

Comando (com variáveis de ambiente configuradas):

```
flutter test test/integration/
```

Pendente com conta admin (hoje sem `TEST_ADMIN_*` no ambiente):

- [ ] grupo público aprovado aparece em Para Você/Conexão (coberto pela lógica
  SQL e pelo diretório; validar na Staging ao aprovar o primeiro grupo).
- [ ] `public_group_directory` listando apenas aprovados.

Checklist manual no aparelho: ver `CHECKLIST-MANUAL.md`, cenário 11.
