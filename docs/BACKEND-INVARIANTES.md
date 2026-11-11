# Backend: invariantes, histórico e regras de alteração

> **Leitura obrigatória antes de alterar qualquer coisa no backend**
> (migrations, RLS, RPCs, triggers, Edge Functions ou Storage).
> Este documento explica **por que** cada regra existe e **o que não pode ser mudado**
> sem quebrar funcionalidades implementadas de propósito.
>
> Atualize este arquivo sempre que criar ou alterar algo relevante no servidor.

---

## 1. Como usar

1. Leia a seção do domínio que vai mexer (feed, grupos, conversas, conexões,
   denúncias, perfis, notificações, storage).
2. Verifique a **tabela de migrations** e o **checklist “não quebre isto”**.
3. Mudou um invariante? Exige:
   - justificativa escrita (segurança/qualidade, não conveniência);
   - atualização deste documento;
   - atualização/adição dos testes de integração correspondentes;
   - revisão de qualquer código do app que dependa de nomes/erros de RPC.
4. Princípio inegociável: **segurança no servidor**. UI pode esconder, mas quem
   bloqueia é RLS/trigger/RPC. Ver `docs/PRINCIPIOS.md`.

Convenções:
- Toda função `security definer` deve ter `set search_path = public`.
- Toda mutação de grupo/conversa/convite é via RPC; não se cria policy de
  INSERT/UPDATE/DELETE nessas tabelas.
- Erros de negócio são `raise exception 'codigo'` e o app depende desses textos
  (não renomeie sem atualizar `app/` e os testes).
- Versão de referência: **1.0.14** (builds 14–18 no Firebase App Distribution).

---

## 2. Baseline anterior à 1.0.14 (resumo)

Estruturas já existentes e que a 1.0.14 usa ou alterou:

| Área | Migrations base | Invariantes que não devem ser esquecidos |
|---|---|---|
| Auth/18+/UFV | `init_auth`, `enforce_ufv_email`, `enforce_adult`, `ufv_email` | 18+ e domínio UFV validados no servidor; perfil criado por trigger |
| Feed original | `feed` | `posts/comments/likes` com RLS |
| Admin/denúncias | `admin_reports` | `admins`, `reports`, `audit_log`; admin só via tabela `admins` |
| Chat | `chat`, `message_requests` | conversa 1:1, pedidos, `messages` só em conversa aceita |
| Social | `social_discovery` | conexões, bloqueios, `can_view_post`, descoberta |
| Moderação | `moderation_play` | diretrizes, bloqueio de conteúdo, `hidden_at`, auto-hide |
| Estudos | `studies_phase1`, uploaders | fora do escopo 1.0.14, mas RLS própria; **não misturar** com grupos |
| Notificações | `notifications` | tipos permitidos, `enqueue_notification`, preferências, FCM |
| Outros | `stickers`, `badges`, `chat_management`, `beta_signups` | figurinhas (admin), selos, gestão de chat, cadastro beta |

Atenção: a 1.0.14 **substituiu** algumas regras do baseline
(`can_view_post`, `feed`, `messages`, `reports` auto-hide, `profiles` update).
A versão vigente é sempre a última migration; não reintroduza a antiga.

---

## 3. Histórico detalhado da 1.0.14

> Ordem de aplicação = nome do arquivo. Cada linha: motivo e o que não alterar.

| Migration | Por que foi criada | Objetos | Não altere sem revisar |
|---|---|---|---|
| `20261109120000_groups_core` | Fundação de grupos | `groups`, `group_members`, `group_roles`, `group_member_roles`, `group_followers`, `group_invites`, `group_audit_events`, `normalize_group_name`, trigger de nome | Índice único público do nome; normalização; não adicione policies de escrita |
| `20261109121000_groups_security` | Permissões e segurança de grupo | helpers `is_group_member`/`has_group_permission`/`can_view_group`, RLS select-only e RPCs (criar/editar/entrar/sair/seguir/cargos/convite/resgate/auditoria) | Checks de permissão, bloqueio de auto-atribuição, cargo do dono, hash do convite, `search_path` |
| `20261109130000_seed_test_accounts` | Preparar contas A/B para testes | Atualiza `profiles` (verified/completo) e consentimento | Já aplicada; para novas contas crie **nova** migration (esta não roda de novo) |
| `20261109140000_feed_topics` | Tópicos estruturados + feeds | `topics` (campi/cursos/eventos), `post_topics` + trigger, `posts.group_id`, `can_view_post` com grupo, `feed_for_you`/`feed_connections` | Fórmula de relevância (3/2/2 + recência), janela de 30 dias, limites de tópicos, filtro de grupo |
| `20261109150000_feed_replies_quotes` | Respostas encadeadas e citação | `comments.parent_id/depth` (máx. 3), `posts.quoted_post_id/was_quote`, `enforce_post_quote` | Limite de profundidade; citação apenas referência (sem copiar conteúdo); exigir `can_view_post` na criação |
| `20261109160000_posts_group_role` | Cargo e snapshot no post | `role_id`, `role_name_snapshot`, `posted_as_group`, `enforce_post_role` | Grupo exige cargo; cargo do grupo certo e atribuído; `post_as_group` só com permissão; snapshot imutável |
| `20261109170000_group_directory` | Diretório público e estatísticas | `group_stats`, `public_group_directory` | `group_stats` exige `can_view_group` (adicionado depois); diretório só público aprovado |
| `20261109171000_remove_group_member` | Gestão de membros | `remove_group_member` | Não remover dono; permissão `manage_members` |
| `20261109180000_group_moderation` | Moderador de grupo | `group_moderate_post/comment`, correção de comentário oculto | Permissão no **grupo do conteúdo**; oculto não é legível |
| `20261112120000_delete_group` | Excluir grupo | `delete_group` (dono/admin), cascata | Só dono/admin; cascata apaga posts do grupo e auditoria |
| `20261112140000_fix_pgcrypto_qualify` | Bug de produção 42883 | `create_group_invite`/`redeem_group_invite` com `extensions.gen_random_bytes/digest` | No Supabase, pgcrypto vive em `extensions`; não remova a qualificação |
| `20261112150000_group_categories` | Categorias oficiais (inventadas antes) | `normalize_group_category`, normalização de legado, CHECK, trigger | Lista fixa: Centro Acadêmico, Atlética, Grupo de Estudos, República, Outros |
| `20261113120000_group_invites_inapp` | Convites sem link | `target_user_id`, `create_group_invite_for_user`, `my_group_invites`, `accept`/`decline_group_invite`, `remove_group_follower`, tipo `group_invite`, preferência `groups` | Exige conexão aceita; 1 uso; notificação; aceite valida destinatário/expiração/revogação/usos/ativo/verificado/diretrizes/arquivado |
| `20261114120000_security_hardening` | Rodada 1 da auditoria | Guard de perfil, conexões `pending`, `start_conversation` restrita, `respond_message_request`, mensagens bloqueadas, denúncias (autor/visível/única/limite/3 denunciantes), feeds com autor ativo/fora de revisão, revogações, subset de cargo, helpers, `created_at` do servidor | Todas as correções; **não reintroduza** policies amplas, links ou auto-hide com 1 denúncia |
| `20261114130000_storage_policies` | Storage de perfil/figurinhas | `profile-media` privado (dono), `stickers` público (escrita admin) | Não tornar `profile-media` público; escrita só em `auth.uid()/...` |
| `20261114140000_admin_profile_actions` | Admin não conseguia alterar perfil alheio | `admin_set_profile_review`, `admin_set_account_status` (auditadas) | App deve usar as RPCs; não voltar a `UPDATE profiles` direto (sem SELECT policy) |
| `20261114150000_revoke_enqueue_notification` | `enqueue_notification` exposta por grant PUBLIC | Revoga `enqueue_notification`/`notification_type_enabled` de PUBLIC/anon/authenticated | Triggers definer continuam podendo chamar; **nunca** conceda ao cliente |
| `20261115120000_security_round2` | Rodada 2 (findings 1–8) | Conta inativa sem leitura/interação; conexões só via RPC; denúncias com `created_at` forçado e alvo visível; bloqueio em comentários/curtidas; avatar/fotos restritos | Checks de `is_active_user(auth.uid())` nas leituras; IDs/rotas de denúncia; paths de mídia |
| `20261115130000_storage_verification` | Documentos de identidade (PII) | Bucket `verification-docs` privado + policies por dono | Nunca tornar público; leitura/escrita só `auth.uid()/...` |
| `20261115140000_fix_profile_guard` | Correção do guard | `pg_trigger_depth()`; restauração da conta A | Em trigger definer, `current_user` é o dono — **não** use para distinguir cliente; a condição de profundidade é intencional |

Migrations temporárias usadas durante o desenvolvimento (reset de senha,
tabela de debug) **não estão no repositório**; o histórico remoto foi ajustado
com `supabase migration repair --status reverted`. Não recrie esses arquivos.

---

## 4. Invariantes por domínio

Para cada item: regra, motivo e consequência de quebrar.

### 4.1 Feed e posts
- `can_view_post` decide: oculto, autor ativo/fora de revisão, bloqueio,
  público/conexões e grupo (via `can_view_group`). **Todo feed espelha isso.**
  - Quebrar: vaza post privado/de grupo, mostra autor suspenso ou viola bloqueio.
- `feed_for_you`: públicos (pessoais de perfil público + grupos públicos
  aprovados), janela de 30 dias, relevância transparente (curso +3, campus +2,
  interesses +2, recência +1 e +1), conta ativa.
  - Quebrar: ranking opaco/aleatório, posts antigos/privados.
- `feed_connections`: próprios + conexões aceitas + grupos públicos seguidos.
- `created_at` de posts/comentários/mensagens/denúncias é **do servidor**
  (`force_server_created_at`). Quebrar permite manipular recência/limites.

### 4.2 Respostas e citações
- Comentários aninhados até **3 níveis** (`parent_id/depth`, trigger).
  Profundidade maior é rejeitada (`profundidade_maxima`).
- Citação guarda somente `quoted_post_id` + `was_quote`, sem cópia de texto.
  O cartão é lido em tempo real sob RLS; inacessível → “Conteúdo indisponível”.
- Citar exige `can_view_post` no momento da criação e não pode citar a si mesmo.
- Quebrar: árvore infinita, vazamento de conteúdo restrito/removido.

### 4.3 Grupos
- **Toda escrita é RPC**; tabelas de grupo têm apenas policies de SELECT.
  - Quebrar: cliente forja membro, cargo, convite, seguidor ou grupo.
- `can_view_group`: exige conta ativa, grupo não arquivado e (admin, membro, ou
  público aprovado/oficial/fora de revisão).
- Nome: público único e normalizado (índice parcial); privado repetível.
- Categorias fixas (5) validadas por trigger; legado normalizado.
- Permissões de cargo: lista fixa, somente quem possui pode conceder (dono
  isento), cargo do dono protegido, ninguém se atribui cargo.
- Post no grupo: exige cargo do próprio grupo, membro ativo e cargo atribuído;
  `posted_as_group` exige `post_as_group`; `role_name_snapshot` é gravado no
  insert e **não muda depois** (cargo à época).
- Convites: **somente in-app**, direcionados a conexão aceita, 1 uso, 7 dias,
  notificação `group_invite`; aceite valida destinatário/expiração/revogação/
  usos/conta ativa/verificada/diretrizes/grupo não arquivado.
  - RPCs de link antigas estão **revogadas**; não reative.
- Remoção de membro/seguidor e exclusão do grupo exigem permissão/dono.

### 4.4 Conexões
- **Não existe policy de INSERT** em `connections`; só `send_connection_request`.
- A RPC exige conta ativa, perfil completo, alvo ativo e não bloqueado.
- Aceite/recusa somente via `respond_connection_request` (não há policy de UPDATE).
- Trigger de notificação ignora bloqueios.
- Quebrar: qualquer um se conecta sozinho e lê posts “só conexões”.

### 4.5 Conversas e mensagens
- `start_conversation` só para **conexão aceita**, contas ativas e sem bloqueio;
  caso contrário, use o fluxo de pedido.
- Pedido: `send_message_request` + `respond_message_request` (sem UPDATE direto).
- `messages` só em conversa aceita, participante ativo, sem bloqueio, respeitando
  `hidden_at`, `cleared_at` e `message_deletions`.
- Apagar para todos: remetente e janela de 5 minutos.
- Quebrar: conversa com estranho, mensagens após bloqueio, spoof de status.

### 4.6 Bloqueios
- Posts, perfis, comentários, curtidas, conversas e conexões filtram bloqueio nos
  **dois sentidos**.
- Quebrar: bloqueado continua vendo/interagindo.

### 4.7 Denúncias
- Trigger valida: autor real do alvo, alvo visível ao denunciante, não denunciar
  a si, snapshot recalculado no servidor, única por denunciante/alvo,
  limite de 20/24h e `created_at` do servidor.
- Auto-hide só com **3 denunciantes distintos** em categoria grave
  (posts, comentários, mensagens, materiais e perfil em revisão).
- `reports_force_created_at` precisa rodar **antes** de
  `reports_validate_target` (ordem alfabética dos triggers). Não renomeie.
- Quebrar: censura em massa, denúncia de conteúdo inacessível, bypass do limite.

### 4.8 Perfis, privacidade e contas inativas
- Guard `guard_profile_sensitive`: cliente não altera `verification_status`,
  `account_status`, `profile_under_review`, `ufv_email`, `cpf_hash`,
  `birth_date`, `created_at`; avatar/fotos só no próprio prefixo `uid/...`.
- Em trigger `security definer`, `current_user` é o dono: a distinção usada é
  `pg_trigger_depth() > 1` (moderação disparada por trigger). Não troque por
  `current_user`/`session_user`.
- Conta inativa não lê feeds/posts/grupos/perfis/conversas/conexões e não
  curte/denuncia.
- `profiles_public` filtra ativo/fora de revisão/bloqueio.
- Admin muda status/revisão somente por `admin_set_account_status` /
  `admin_set_profile_review` (auditadas).

### 4.9 Notificações
- `enqueue_notification` e `notification_type_enabled` são internas (revogadas
  de PUBLIC); só triggers/RPCs definer chamam.
- Tipo `group_invite` é válido e mapeado à preferência `groups`.
- Quebrar: spam/phishing de notificação ou erro de constraint em convites.

### 4.10 Storage
- `profile-media`: privado; leitura autenticada; escrita/remoção só em
  `auth.uid()/...`.
- `verification-docs`: privado; somente o dono (PII).
- `stickers`: leitura pública; escrita admin.
- `delete-account` deve apagar `profile-media`, `verification-docs` e `stickers`
  da pasta do usuário.
- Quebrar: exposição de documentos/identidade ou perda de avatares.

### 4.11 Edge Functions
| Função | Regra |
|---|---|
| `delete-account` | Exige JWT do próprio usuário; apaga buckets e conta |
| `verify-cin` | Exige JWT; usa service role para `verification_attempts`/perfil |
| `import-telegram-pack` | Exige JWT + admin em `admins` |
| `send-push` | Exige segredo do webhook; sem JWT público |
| `giphy-search`, `study-file-url` | Exigem JWT |

---

## 5. Catálogo de RPCs e erros esperados

Assinaturas e códigos são contrato com o app. Renomear/alterar assinatura
requer atualizar `app/lib/...` e os testes.

| RPC | Principais checagens | Erros esperados |
|---|---|---|
| `create_group` / `update_group` | ativo, verificado, diretrizes, perfil completo, limite 3/24h | `conta_inativa`, `nao_verificado`, `diretrizes_necessarias`, `perfil_incompleto`, `limite_de_grupos`, `nome_publico_em_uso`, `categoria_invalida` |
| `request_public_group` / `admin_review_group` | dono/gestor; admin | `forbidden`, `nome_publico_em_uso` |
| `join_group` / `leave_group` | público aprovado; dono não sai | `grupo_indisponivel`, `conta_inativa`, `dono_nao_pode_sair` |
| `follow_group` / `unfollow_group` | público aprovado | `grupo_indisponivel`, `conta_inativa` |
| `create_group_role` / `update_group_role` / `delete_group_role` | `manage_roles`; subset de permissões | `forbidden`, `permissao_invalida`, `permissao_nao_permitida`, `cargo_sistema` |
| `assign_group_role` / `remove_group_role` | `manage_roles`; não auto; dono protegido | `nao_pode_se_atribuir`, `cargo_sistema`, `cargo_de_outro_grupo`, `usuario_nao_membro`, `cargo_do_dono` |
| `create_group_invite_for_user` | `manage_invites`, conexão, alvo ativo | `sem_conexao`, `destinatario_inativo`, `ja_e_membro` |
| `accept_group_invite` / `decline_group_invite` | destinatário, validade, revogação, usos, grupo não arquivado | `convite invalido`, `convite revogado`, `convite expirado`, `convite esgotado`, `convite de outro usuario`, `grupo_indisponivel` |
| `remove_group_member` / `remove_group_follower` | `manage_members` | `forbidden`, `nao_pode_remover_dono` |
| `delete_group` | dono/admin | `forbidden` |
| `group_moderate_post/comment` | `moderate_content` no grupo | `forbidden`, `post_de_grupo_necessario`, `comentario_de_grupo_necessario` |
| `feed_for_you` / `feed_connections` | conta ativa | vazio se inativa |
| `send_connection_request` / `respond_connection_request` | ativo, alvo ativo, bloqueio, perfil | `blocked`, `destinatario_inativo`, `conta_inativa` |
| `start_conversation` | conexão aceita, ativo, sem bloqueio | `use_message_request`, `blocked`, `conta_inativa` |
| `send_message_request` / `respond_message_request` | regras de pedido/bloqueio | `blocked`, `message too long` |
| `admin_set_account_status` / `admin_set_profile_review` | admin | `forbidden`, `status invalido` |

Erros de conteúdo/moderação: `conteudo_proibido:<categoria>`,
`diretrizes_necessarias`, `conta_inativa`.
Erros de post/cargo: `cargo_obrigatorio`, `cargo_nao_atribuido`,
`cargo_de_outro_grupo`, `sem_permissao_publicar_em_nome`,
`selo_exige_grupo_publico`, `publicacao_inacessivel`.
Erros de denúncia: `alvo_invalido`, `alvo_inacessivel`,
`nao_pode_denunciar_a_si`, `limite_denuncias`.
Erros de perfil/mídia: `caminho_invalido`.

---

## 6. Ordem de triggers e detalhes frágeis

- `reports_force_created_at` **deve** rodar antes de `reports_validate_target`.
- `set_comment_thread` calcula `depth` (0–3) e valida o mesmo post.
- `enforce_post_role` grava `role_name_snapshot` e valida permissões.
- `enforce_post_quote` exige `can_view_post` e marca `was_quote`.
- `validate_report_target` depende de `can_view_post`, participante e status do
  material.
- `guard_profile_sensitive` depende de `pg_trigger_depth()` (não use
  `current_user`).
- `group_audit` é interna (revogada de PUBLIC).
- Funções `security definer` sempre com `search_path = public`.

---

## 7. Runbook operacional

### Aplicar migrations
```bash
supabase link --project-ref <ref>   # gera/valida config.toml e .temp
supabase migration list             # Local vs Remote
supabase db push --yes              # aplicar pendentes
```
- Projeto atual: `lgsyuusotabxrjqgyqdq` (config em `supabase/config.toml`).
- Histórico remoto foi inicializado por `migration repair` (projeto antigo usava
  Management API). Se aparecer “Remote migration versions not found”, repare a
  versão com `--status reverted` em vez de recriar migrations temporárias.

### Edge Functions
```bash
supabase functions deploy delete-account
```
- Mudou lista de buckets? Atualize a função **e** este documento.

### Segredos e testes
- Nunca commitar `.env`, chaves ou tokens; `.env` é gitignored.
- Testes de integração usam `TEST_USER_A/B_*` e `TEST_ADMIN_*` no `app/.env`.
- Rodar com `-j 1` (suíte compartilha contas; há rate limit de login).
- O helper de login tem throttle de 2,2 s; não remova.

---

## 8. Mapa de testes (o que protege cada invariante)

| Arquivo | Protege |
|---|---|
| `groups_rls_test` | grupo privado invisível, nome público único, convites (revogado/expirado), auto-atribuição de cargo |
| `group_categories_test` | lista oficial de categorias (criar/editar) |
| `posts_group_role_test` | cargo obrigatório, permissão de publicar em nome, snapshot |
| `group_moderation_test` | moderação de grupo, citação/resposta em grupo, bloqueio |
| `group_invites_inapp_test` | convite direcionado (aceite/recusa), sem conexão falha, remover seguidor |
| `public_group_feed_test` | aprovação admin → feed/diretório |
| `replies_quotes_test` | limite de 3 níveis, citação inacessível, `was_quote` |
| `security_hardening_test` | perfil, conexões, conversas/bloqueio, denúncias, RPCs legadas, cargo, `created_at`, revisão de perfil |
| `security_round2_test` | conta inativa, conexões sem insert direto, bloqueio em comentários/likes, denúncia (visibilidade/data), avatar/fotos, `verification-docs` |
| `rls_isolation_test` | notificações e tokens isolados por usuário |
| `supabase_setup_test` | login das contas A/B |
| `edge_function_test` / `form_submit_test` | pulam sem as variáveis externas |

Regras de execução:
- `flutter analyze` e `flutter test` (unit/widget) sempre.
- Integração: `flutter test test/integration/ -j 1` com `.env` carregado.
- Cleanup dos testes: grupos `ztest%` são apagados; **conexões e bloqueios entre
  A/B são removidos** (outros testes dependem disso); limite de 3 grupos/24h.
- Pendência manual: auto-hide de perfil com 3 denunciantes exige 3ª conta de
  teste (A/B/admin = 2 não-autores por alvo).

---

## 9. Decisões registradas

- **Play Store fora do escopo** nesta fase: distribuição 100% Firebase App
  Distribution (grupo UFV Beta). Play só volta se alguma mudança irreversível
  puder afetar a aprovação futura.
- **Convites não saem do app**: sem link/código copiável.
- **Findings baixos adiados (não esquecidos)**:
  1. aceite de convite com grupo `under_review`;
  2. validação de host de `gif_url`/`sticker_path` em mensagens;
  3. `is_active_user` como oráculo e alvo ativo em `send/respond` de mensagem;
  4. posts de membro removido do grupo continuam visíveis;
  5. rate limit de `submit_beta_signup` e enumeração por duplicidade;
  6. `verify-cin` grava `pending` com QR inválido;
  7. policies de `study-media` e limpeza na exclusão de conta.

---

## 10. Checklist “não quebre isto”

- [ ] Não adicionar policy de INSERT/UPDATE/DELETE em `groups`, `group_*`,
  `connections`, `conversations`, `conversation_participants`, `messages` ou
  `reports` (mutação só por RPC quando previsto).
- [ ] Não flexibilizar `can_view_post`/`can_view_group`/`feed_*`
  (bloqueio, autor ativo, fora de revisão, membro/público).
- [ ] Não remover os checks de `is_active_user(auth.uid())` de leitura.
- [ ] Não reintroduzir convite por link nem RPCs `create_group_invite`/
  `redeem_group_invite`.
- [ ] Não remover `pg_trigger_depth()` do guard de perfil.
- [ ] Não reverter ban/suspensão para `UPDATE profiles` direto.
- [ ] Não remover `role_name_snapshot`/trigger de cargo.
- [ ] Não permitir grupo post sem cargo ou cargo de outro grupo.
- [ ] Não permitir auto-atribuição de cargo nem remover cargo do dono.
- [ ] Não alterar o limite de 3 níveis de resposta.
- [ ] Não copiar conteúdo de citação para o banco.
- [ ] Não alterar nomes/ordem de triggers de denúncia.
- [ ] Não reduzir o auto-hide para menos de 3 denunciantes distintos.
- [ ] Não remover validação de autor/visibilidade/limite/duplicidade de denúncia.
- [ ] Não tornar `profile-media` ou `verification-docs` públicos.
- [ ] Não permitir escrita fora de `auth.uid()/...` no storage.
- [ ] Não conceder `enqueue_notification`/`notification_type_enabled` ao cliente.
- [ ] Não remover `set search_path = public` de funções definer.
- [ ] Não remover o throttle de login nem o cleanup de conexões/bloqueios dos
  testes.
- [ ] Não alterar categorias sem decisão de produto e migration de normalização.
- [ ] Não mexer em regras de estudos/notificações do baseline sem revisar as
  policies próprias.
- [ ] Toda mudança de invariante: atualizar este arquivo + testes + app.

---

## 11. Como atualizar este documento

Ao criar uma migration/Edge Function:
1. Adicione uma linha na tabela da seção 3 (motivo + “não altere”).
2. Atualize a seção de invariantes afetada.
3. Atualize o mapa de testes (seção 8) e o checklist (seção 10).
4. Se mudar decisão (ex.: Play, convites), registre na seção 9.
5. Rode `flutter analyze` + testes e cite o resultado no PR/commit.
