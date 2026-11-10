# Roadmap em Blocos

## Decisões técnicas

| Tema | Decisão |
|---|---|
| Plataforma | **Android primeiro**; arquitetura preparada para iOS |
| Framework | **Flutter** |
| Backend | Supabase (auth, Postgres, storage, Edge Functions) |
| Mapa | Sem localização de usuários no MVP; lugares/eventos no futuro |
| Estudos | Conteúdo misto com curadoria; sem prova vazada |
| Romance | Congelado; volta como modo 18+ opcional no futuro |
| Contas de casal | Duas contas vinculadas (fase futura) |
| IA | On-device/Edge com citação; sem treinar em dados do usuário |
| Assinatura | Duo R$ 10/mês (2 vagas); Play Billing 15% |
| Receita | Sem anúncios e sem venda de dados |
| Transparência | Políticas e roadmap públicos; métricas internas |

## Blocos

### B0 — Fundação
**Status:** ✅ Flutter, Riverpod, go_router, tema e rotas.

### B1 — Identidade 18+
**Status:** ✅ Auth Supabase; emails `@alunos.ufv.br` e `@ufv.br`; 18+ no servidor.

### B2 — Perfil & Onboarding
**Status:** ✅ Perfil, fotos, prompts, favoritos, perfil público.

### B3 — Descoberta & Match
**Status:** ✅ Feed social (abas Para Você/Conexão com relevância transparente,
FAB, publicação com tópicos/cargo, citações e respostas de até 3 níveis),
descobrir, conexões e bloqueios. Grupos para o campus (1.0.14): schema, RLS,
cargos/convites, diretório e aprovação de grupo público — ver
`docs/GRUPOS.md`. Romance pendente.

### B4 — Chat & Segurança
**Status:** ✅ Mensagens, pedidos, moderação e denúncias.

### B5 — AI Coach
**Status:** ⏳ Futuro; depende de assinatura.

### B6 — Localização & Mapa
**Status:** ⏸️ Adiado. Sem localização de usuários. Mapa de lugares/eventos no futuro.

### B7 — Assinatura
**Status:** ⏳ Duo R$ 10; Play Billing quando cobrar; UCB 11% só com CNPJ.

### B8 — Confiança & Denúncia
**Status:** ✅ Denúncias, bloqueios e auditoria. Expandir categorias e ocultação automática.

### B9 — Admin/Moderação
**Status:** ✅ Painel de denúncias. Adicionar remoção/restauração de conteúdo.

### B10 — Beta & Lançamento
**Status:** 🚧 Play Store: conta pessoal, teste interno → fechado; 12/14 para produção.

### B11 — Play readiness + moderação
**Entrega:** remover auto-update, exclusão de conta, termos/diretrizes, permissões
mínimas, AAB, moderação server-side.
**Pronto quando:** AAB aprovado no teste interno e política de UGC completa.

### B12 — Estudos MVP
**Entrega:** 10–20 disciplinas da UFV; materiais, Q&A e grupos; conteúdo misto;
curadoria; integridade acadêmica.
**Depende de:** B11.
**Pronto quando:** alunos usam semanalmente e o Q&A tem resposta.

### B13 — Professores/servidores
**Entrega:** perfis oficiais, materiais, avisos e Q&A; sem DM com alunos.
**Depende de:** B12.

### B14 — Alumni
**Entrega:** mentoria, vagas e eventos; verificação manual; DM opt-in.
**Depende de:** B13.

### B15 — Multiuniversidade
**Entrega:** `universities`, domínios, catálogos, embaixadores; 3–5 federais.
**Depende de:** B14.

### B16 — Conexa Escola
**Entrega:** produto separado para menores; estudo + Q&A moderado; sem DM/feed/
fotos/romance; parceiro escolar; revisão jurídica.
**Depende de:** B15 e validação do universitário.

### B17 — Escala
**Entrega:** serviços, marketplace, relatórios, auditorias, time e empregos.

## Contas de casal

- Fase futura; cada pessoa com sua conta e verificação.
- Consentimento dos dois; vínculo exibido no perfil.

## Direção visual

- Papel `#F6F2EA`, tinta `#14130F`, acento verde-petróleo `#0F5C5C`.
- Newsreader + IBM Plex Sans.
- Muito espaço em branco, cards de prompt grandes.

## Riscos

- Moderação e suporte custam; receita precisa acompanhar.
- Conteúdo de estudos: qualidade, copyright e provas vazadas.
- Menores: produto separado, com proteção e revisão jurídica.
- Universidade: marca, parcerias e política interna.
- Free tiers servem para MVP; escala tem custo.
