# Roadmap de usabilidade do Conexa

> Documento interno. A versão pública fica em `docs/roadmap.html`, sem datas e sem detalhes técnicos.

## Visão

Ser a camada de confiança da vida universitária: comunidade verificada, estudos,
eventos e serviços do campus. Começa pela UFV e só depois expande.

Princípios:
- usabilidade antes de volume de recursos;
- segurança e privacidade no servidor;
- sem anúncios e sem venda de dados;
- 18+ no Conexa Universitário;
- feedback dos testadores define prioridade.

## Etapas

| Etapa | Status | Foco | Entregas |
|---|---|---|---|
| Base beta 1.0.12 | Concluída | O essencial funciona | Feed, descoberta, conexões, conversas, estudos fase 1, moderação e badges |
| 1.0.13 — usabilidade essencial | Push reais validados; encerramento após revisões finais | Não deixar o usuário perdido ou sem retorno | Notificações, central, tutorial, checklist, ajuda, busca e acessibilidade |
| Feed e Grupos | Concluída (1.0.14) | Copiar a estrutura de feed com duas abas e criar grupos com cargos | Para Você/Conexão, FAB de publicar, posts citados, respostas encadeadas e grupos com convites/cargos |
| Canal de feedback | Concluída (1.0.15) | Ouvir os testadores e transformar relatos em melhoria | Bugs e sugestões no app, print opcional, protocolo, triagem admin, exportação e agentes de análise |
| Privacidade e confiança | Concluída (1.0.17) | Reduzir assédio, dar controle e cumprir LGPD | Dispositivos conhecidos, exportar dados, mutes de usuário/palavras, apelação e controle de respostas |
| Feed social P1 | Concluída (1.0.18) | Paridade de feed sem perder segurança | Bookmark, repost, enquete, edição, fixar, rascunhos, agendamento, alt text, menções, notificações de interação e imagens |
| Chat social P2 | Concluída (1.0.19) | Conversas mais próximas de um mensageiro moderno | Grupos, reply, reações, edição, mídia, pin/mute/archive e digitando; sem E2EE |
| Descoberta P3 | Concluída (1.0.20) | Encontrar conteúdo e medir o próprio alcance | Busca global, feeds personalizados, não interessado, insights agregados e copiar link |
| Grupos e estudos P4 | Concluída (1.0.21) | Fechar o ciclo de grupo e estudo | Chat do grupo, eventos, analytics agregado, Q&A, materiais salvos e avaliações |
| Hardening P5 | Concluída | Corrigir dívidas e remover custos desnecessários | Remoção do 2FA e vídeo, exportação em arquivo, termos gerenciáveis, mídia agendada, membros do chat, RSVP, busca em comentários, views, anexos de Q&A e comentários em avaliações |
| Estudos fase 2 | Planejada | Aprofundar o valor de estudo | Q&A, grupos, materiais salvos, avaliações e status de aprovação |
| Vida no campus | Planejada | Ir além da comunidade | Eventos, serviços, avisos, professores/servidores e alumni |
| Contínuo — confiança | Contínuo | Segurança e transparência | Status de denúncias, privacidade, bloqueios, preferências e moderação |
| Antes da Play | Planejada | Entrar na loja com segurança | 12 testadores por 14 dias, remoção do SDK beta, In-App Updates, Data safety e classificação 18+ |
| Pós-beta | Futuro | Crescer sem perder a proposta | Outras universidades, alumni e avaliação do modo escola |

Sem datas. A ordem pode mudar com o feedback, mas não se antecipa uma etapa
antes de a anterior estar estável.

## 1.0.13 — usabilidade essencial

### Notificações

Categorias:
- pedido de mensagem;
- nova mensagem em conversa aceita;
- solicitação de conexão;
- conexão aceita;
- material pendente para administradores;
- material aprovado/rejeitado para o autor.

Regras:
- não notificar bloqueados, recusados ou conversas não aceitas;
- nunca notificar o remetente pela própria ação;
- push de mensagem usa o nome público do remetente e a contagem de não lidas
  daquele remetente; o texto da mensagem nunca vai no push;
- sem PII no payload além do nome público e IDs necessários para a rota;
- preferências controlam push e central;
- as abas funcionais continuam mostrando o evento.

### Backend

Tabelas:
- `device_tokens`;
- `notification_preferences`;
- `notifications` (fila e histórico).

Gatilhos:
- inserção de conversa pendente;
- inserção de mensagem em conversa aceita;
- inserção/atualização de conexão;
- inserção/atualização de material de estudo.

Envio:
- Edge Function `send-push`;
- FCM HTTP v1;
- conta de serviço dedicada com permissão apenas de envio;
- segredo no Supabase, nunca no app ou no repositório;
- Database Webhook em `notifications` insert;
- cron de retry para pendentes/falhas;
- registro de `pushed_at`, tentativas e erro;
- remoção de tokens inválidos.

### App

- Firebase Core, Firebase Messaging e notificações locais.
- Registro do token após login.
- Atualização em `onTokenRefresh`.
- Remoção obrigatória do token e das notificações locais no logout.
- Permissão Android 13+ contextual.
- Central em `/notifications`, com sino, badge, leitura e tempo real.
- Busca ao abrir e ao voltar do segundo plano.
- Deep links:
  - `/chats?tab=requests`;
  - `/chats?tab=connections`;
  - `/chats/:id`;
  - `/studies/material/:id`;
  - `/admin/studies`.
- `ChatListScreen` aceita aba inicial.

### Tutorial e usabilidade

Tutorial em 5 telas:
1. O que é o Conexa.
2. Perfil e descoberta.
3. Conexões e conversas.
4. Estudos.
5. Segurança, beta e suporte.

Com pular, progresso, não mostrar novamente e rever em Ajuda/Ajustes.

Também:
- checklist de perfil essencial/opcional;
- estados vazios;
- FAQ e contato;
- busca de conversas;
- acessibilidade e desempenho.

### Operação

- Checklist de configuração do Firebase/Supabase.
- Runbook de falhas de push.
- Tela de diagnóstico administrativo:
  - pendentes, enviadas e com erro;
  - última tentativa e erro;
  - token mascarado e último uso.
- Token bruto apenas no painel do Supabase.
- Rotação da conta de serviço e revogação em suspeita.
- Logs sem PII, sem token bruto e sem conteúdo.

### Critérios de aceite

- Quatro categorias de notificação funcionando.
- Push de mensagem apenas "Nova mensagem".
- Central com badge, leitura e tempo real.
- Preferências respeitadas.
- Logout sem vazamento de token.
- Estudos com autor e administradores.
- Sem duplicidade, sem PII e sem notificação indevida.
- Tutorial, busca, estados vazios e acessibilidade funcionando.
- `flutter analyze` limpo.
- Build 1.0.13 distribuído e testado com duas contas.

Teste real de push já validado pelas duas contas. Os itens finais de encerramento são as revisões de acessibilidade, estados vazios e atualização da central ao voltar do segundo plano.

## 1.0.15 — Canal de feedback

Objetivo: ouvir os testadores e transformar relatos em correções e melhorias,
sem abrir mão das regras de segurança.

### App

- Entrada em **Ajuda** e **Ajustes**.
- Formulário de bug com título, descrição, passos, esperado, acontecido e
  aparelho/sistema.
- Print opcional (JPEG comprimido, até 5 MB).
- Formulário de sugestão com problema, proposta e impacto.
- Protocolo visível (`BUG-000123` / `SUG-000045`).
- “Meus envios” com o status de cada item.

### Backend

- Tabelas `bug_reports` e `suggestions`.
- RLS: usuário só vê o próprio feedback; status e exclusão só admin.
- Campos do sistema e protocolo definidos no servidor.
- Limite de 20 envios por dia por tipo.
- Bucket privado `feedback-media` (dono/admin, tipo e tamanho limitados).
- RPC `export_feedback`, restrita a admin e sem identidade do autor.
- Exclusão de conta apaga feedbacks e prints.

### Admin

- Tela `/admin/feedback` com abas, filtros, detalhe, print e mudança de status.

### Operação

- `automation/export-feedback.ps1` gera `feedback/Bugs.md` e
  `feedback/Sugestoes.md` (e prints com `-IncludeScreenshots`).
- Três agentes: triagem de bugs, revisão de sugestões e implementação com
  aprovação humana.

### Critérios de aceite

- Usuário envia bug/sugestão e recebe protocolo.
- Nenhum usuário lê, edita ou apaga feedback de outro.
- Admin triagem e muda status.
- Exportação funciona e não expõe o autor.
- `flutter analyze` limpo e testes de integração passando.
- Build 1.0.15+19 distribuída no App Distribution.

## 1.0.17 — Privacidade e confiança

Objetivo: dar controle ao usuário, reduzir assédio e cumprir a LGPD sem abrir
mão da moderação forte.

### Entregas

- Dispositivos conhecidos e “sair de todos os aparelhos”.
- Exportação dos dados do titular em JSON (copiar e compartilhar arquivo).
- Silenciar usuários e palavras; feed, comentários e descoberta respeitam.
- Controle de quem pode responder (`anyone`/`connections`).
- Status da denúncia visível e apelação única, com decisão do admin.
- Política de moderação forte documentada; termos gerenciáveis pelo admin.

### Critérios de aceite

- Usuário silenciado some do feed/comentários/descoberta, sem virar bloqueio.
- Post restrito a conexões rejeita resposta de estranho no servidor.
- Denunciante vê status e consegue apelar uma vez; admin resolve.
- Exportação não inclui `cpf_hash` nem dados de outra conta.
- Nenhuma tela de 2FA é exibida; login usa a conta institucional.
- `flutter analyze` limpo e suíte de integração passando.

## 1.0.18 — Feed social P1

Objetivo: fechar lacunas de feed sem abrir mão de moderação, privacidade e
custo baixo.

### Entregas

- Bookmark e lista própria (sem expor quem salvou).
- Repost simples e citação separados.
- Enquete de 2–4 opções, 24h/3d/7d, voto único e resultados agregados.
- Edição em até 15 min, com marca “editado”; fixar um post por perfil.
- Rascunhos e agendamento (5 min–30 dias; 10 pendentes) com publicação via
  `send-push`/cron.
- Alt text por mídia, menções a conexões e notificações de curtida, resposta,
  menção e repost.
- Imagens (até 4) no R2 privado, com cota de 30 imagens/24h e 500 MB/30d.
- Upload de vídeo pausado por custo; pode voltar como recurso de assinante.
- Moderação por palavras-chave continua valendo para texto e mídia é denunciável.

### Limitações conhecidas

- Upload de vídeo está desativado no MVP.
- Rascunho/agendamento com mídia usa imagens.
- URL de mídia assinada expira em 1h; o app renova.

### Critérios de aceite

- Bookmark, repost, enquete, edição, fixação e menção funcionam com RLS.
- Post agendado publica e respeita diretrizes, tópicos e menções.
- Mídia só assina para quem pode ver o post; cota e tipo são validados.
- Notificações respeitam a preferência `interactions`.
- `flutter analyze` limpo e suíte de integração passando.

## 1.0.19 — Chat social P2

Objetivo: melhorar a conversa sem abrir mão da moderação server-side.

### Entregas

- Chat em grupo com título, criador, participantes e limite de 10 grupos/24h.
- Responder mensagem (somente na mesma conversa) e editar texto em 15 min.
- Reações por mensagem, uma por usuário, com contagem agregada.
- Imagem (5 MB) e PDF (10 MB) no R2 privado, com cota; upload de vídeo pausado.
- Fixar, silenciar e arquivar por participante; silenciado não recebe push.
- Indicador “está digitando”, com expiração de 10s.
- Lista com fixados no topo, ícones de silenciado/arquivado e filtro de arquivadas.
- Imagens do chat usam miniatura.
- Sem E2EE no MVP; moderação e conteúdo continuam server-side.

### Limitações conhecidas

- Upload de vídeo no chat está desativado no MVP.
- URL de mídia do chat expira em 1h e é renovada.

### Critérios de aceite

- Grupo só com conexões ativas; participante não vira dono por UPDATE direto.
- Reply cross-conversa é bloqueado no servidor.
- Reação/edição/pin/mute/archive funcionam com RLS.
- Mídia só assina para participante ativo da conversa.
- Silenciado não recebe push de mensagem.
- `flutter analyze` limpo e suíte de integração passando.

## 1.0.20 — Descoberta P3

Objetivo: facilitar encontrar conteúdo e entender o próprio alcance sem
sacrificar privacidade.

### Entregas

- Busca global de posts com full-text em português e índice GIN.
- Feeds personalizados com nome e até 5 tópicos; limite de 20 por usuário.
- “Nao tenho interesse” por post, removendo de feed, busca e feed custom.
- Insights agregados dos próprios posts: curtidas, respostas, reposts, salvos,
  votos em enquetes e top posts; sem identidade de terceiros/demografia.
- Copiar link do post via deep link `conexa://feed/<id>`.

### Limitações conhecidas

- Não há página web pública de post; o link é deep link do app.
- Busca cobre conteúdo do post; não inclui comentários.
- Não há métrica de impressões/views.
- “Nao interessado” não tem tela de desfazer; o post continua acessível por link.

### Critérios de aceite

- Busca respeita bloqueio, mute, conta ativa e não interessado.
- Feed custom só retorna posts visíveis e com tópicos válidos.
- Não interessado remove do feed/busca sem quebrar o detalhe por link.
- Insights contam apenas posts do próprio usuário.
- `flutter analyze` limpo e suíte de integração passando.

## 1.0.21 — Grupos e estudos P4

Objetivo: conectar a comunidade do campus e aprofundar o estudo colaborativo.

### Entregas

- Chat do grupo do campus, único por grupo, só para membros, com sync de
  entrada/saída e título.
- Eventos do grupo com título, descrição, local, início/fim e duração.
- Insights agregados do grupo: membros, seguidores, posts, respostas, curtidas,
  mensagens e eventos futuros.
- Q&A por disciplina: perguntas, respostas, voto, resposta aceita e status
  resolvido.
- Materiais salvos e avaliação de 1–5 estrelas com média agregada.
- Conteúdo de Q&A passa por diretrizes, palavras-chave e denúncia.

### Limitações conhecidas

- Chat do grupo usa a mesma infraestrutura do P2, sem E2EE.
- Eventos não têm RSVP/lembrete nesta versão.
- Q&A não tem anexos nem busca própria.
- Avaliações não têm comentário; apenas nota.

### Critérios de aceite

- Chat do grupo abre apenas para membro e acompanha entrada/saída.
- Evento só é criado por gestor/dono; leitura respeita `can_view_group`.
- Insights do grupo não expõem identidade de terceiros.
- Q&A aceita resposta só pelo autor da pergunta; voto é único.
- Salvar/avaliar funciona só em material aprovado e visível.
- `flutter analyze` limpo e suíte de integração passando.

## 1.0.22 — Hardening P5

Objetivo: corrigir dívidas acumuladas, remover custo desnecessário e fechar
lacunas de moderação, mídia e colaboração.

### Entregas

- 2FA removido do app (login pela conta institucional).
- Upload de vídeo desativado no feed/chat; imagens e PDF seguem.
- Exportação de dados em arquivo compartilhável.
- Termos de moderação gerenciáveis pelo admin, com seed dos termos atuais.
- Renovação de URL de mídia e telas de “publicações ocultas” com desfazer.
- Mídia em rascunho/agendamento (imagens) e GC diário de órfãos.
- Miniatura para imagens do chat.
- Adicionar/remover membros de chat em grupo.
- RSVP de eventos e lembrete push.
- Busca em comentários e views agregadas.
- Anexos PDF/imagem e busca no Q&A.
- Comentário público em avaliações de material.

### Limitações conhecidas

- Vídeo upload fica para uma fase de assinantes.
- Página web pública de post não existe; link é deep link.
- E2EE não será implementado enquanto a moderação server-side for requisito.
- Revogação individual de sessão fica fora; “sair de todos” permanece.

### Critérios de aceite

- Nenhuma referência a 2FA no app.
- Vídeo rejeitado no servidor para não assinantes.
- Termo novo bloqueia conteúdo sem deploy.
- Agendamento com imagem publica e anexa mídia.
- Órfãos de mídia não crescem sem controle.
- Chat permite adicionar/remover membros.
- Evento tem RSVP e lembrete.
- Busca em comentários e Q&A funciona com RLS.
- Views deduplicadas por dia.
- Avaliação com comentário público moderado.
- `flutter analyze` limpo e suíte de integração passando.

## Matriz de testes

| Cenário | Resultado esperado |
|---|---|
| Permissão permitida | Push chega e central registra |
| Permissão negada | Sem push; central e badges funcionam |
| Foreground | Sem duplicidade; central atualiza |
| Background | Notificação aparece; toque abre a rota |
| App fechado | Notificação chega quando o sistema permite |
| Force-stopped | Pode não chegar; central busca ao abrir |
| Token renovado | Tabela atualizada; envio continua |
| Logout/login com outra conta | Nenhuma notificação da conta anterior |
| Duas contas e duas conversas | Cada uma recebe só o que é seu |
| Bloqueado/recusado | Nenhuma notificação indevida |
| Estudo do autor | Aprovado/rejeitado notifica o autor |
| Estudo do administrador | Pendente notifica admins |
| Webhook falha | Cron faz retry |
| FCM falha | Erro registrado; central permanece |
| Retry | Sem duplicidade |
| Deep link | Abre a tela correta |
| Preferência desligada | Sem push e sem item na central |
| Conteúdo do push | Apenas texto genérico, sem PII |
| Central | Não lidas, marcar lida, marcar todas, tempo real |
| Tutorial | 5 telas, pular e rever |
| Busca/estados vazios | Funcionam em tela pequena e fonte grande |

## Riscos residuais

- FCM pode atrasar ou não entregar; a central cobre.
- A conta de serviço pode ser comprometida; mitigada com menor privilégio, segredo e rotação.
- Configuração manual pode falhar; mitigada com checklist, diagnóstico e retry.
- Economia de bateria pode atrasar push; a central cobre.
- O FCM e o Google veem o payload técnico; por isso ele é mínimo.

## Não objetivos da 1.0.13

- Q&A e grupos de estudo (fase 2 de estudos).
- Eventos e serviços do campus (1.0.16).
- Play Store e cobrança.
- Central de notificações com conteúdo de mensagem.
- Notificações por email.
- iOS.
