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
| Feed e Grupos | Próxima | Copiar a estrutura de feed com duas abas e criar grupos com cargos | Para Você/Conexão, FAB de publicar, posts citados, respostas encadeadas e grupos com convites/cargos |
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
- push de mensagem apenas com "Nova mensagem", sem remetente e sem conteúdo;
- sem PII no payload: apenas IDs de rota;
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

- Q&A e grupos de estudo (1.0.14).
- Eventos e serviços do campus (1.0.15).
- Play Store e cobrança.
- Central de notificações com conteúdo de mensagem.
- Notificações por email.
- iOS.
