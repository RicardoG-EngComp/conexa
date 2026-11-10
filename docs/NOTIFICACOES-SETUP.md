# Notificações: configuração e runbook

> Documento interno. Não inclui segredos e não deve ser publicado com chaves.

## O que já está pronto

- Tabelas `device_tokens`, `notification_preferences` e `notifications`.
- Gatilhos de pedido, mensagem, conexão, conexão aceita, estudo pendente e estudo aprovado/rejeitado.
- Edge Function `send-push` publicada com verificação de JWT desativada; ela exige o segredo do webhook.
- Workflow de retry a cada 10 minutos.
- App 1.0.13 com permissão, token, central, preferências, tutorial e deep links.
- Diagnóstico admin em Administração → ícone de notificações.
- FCM ativado e OAuth/FCM validados com um token de teste inválido; o token foi removido.
- Conta de serviço `conexa-push` com papel de envio FCM e chave ativa.
- Segredos `FCM_SERVICE_ACCOUNT` e `WEBHOOK_SECRET` gravados no Supabase.
- Trigger `trg_conexa_push_webhook` com `pg_net` + Vault no lugar do webhook manual.
- Segredos `NOTIFICATION_FUNCTION_URL` e `NOTIFICATION_WEBHOOK_SECRET` gravados no GitHub.
- Retry manual da Edge Function respondeu `processed: 0`.

## Pendências reais

1. Fazer commit/push do workflow `.github/workflows/notification-retry.yml` para o retry agendado existir no GitHub.
2. Testar com aparelho real: instalar 1.0.13, permitir notificações e receber um push de outra conta.

As seções manuais abaixo continuam servindo para auditoria, rotação e recuperação.

## 1. Ativar o FCM

No projeto Firebase `conexa-20a9b`:

1. Abra o Console do Firebase.
2. Confirme que o app Android `com.ricardogengcomp.conexa` existe.
3. Ative a API **Firebase Cloud Messaging API** no Google Cloud, se ainda não estiver ativa.
4. O `google-services.json` já está no app.

## 2. Criar a conta de serviço

No Google Cloud, projeto `conexa-20a9b`:

1. IAM e administração → Contas de serviço → Criar conta de serviço.
2. Nome sugerido: `conexa-push`.
3. Não dê Owner nem Editor.
4. Conceda apenas a permissão de envio do FCM:
   - papel **Firebase Cloud Messaging API Admin**, se disponível;
   - ou papel personalizado com `cloudmessaging.messages.create`.
5. Crie uma chave JSON.
6. Não coloque o JSON no repositório, no app, em prints ou em chats.
7. Rotacione a chave a cada 90 dias ou imediatamente se houver suspeita.

## 3. Segredos no Supabase

No painel do Supabase, projeto `lgsyuusotabxrjqgyqdq`:

1. Edge Functions → Secrets.
2. Crie:
   - `FCM_SERVICE_ACCOUNT`: conteúdo completo do JSON da conta de serviço;
   - `WEBHOOK_SECRET`: uma string aleatória longa, por exemplo gerada com `openssl rand -hex 32`.
3. Salve.

Alternativa via CLI:

```powershell
npx -y supabase@latest secrets set --project-ref lgsyuusotabxrjqgyqdq `
  FCM_SERVICE_ACCOUNT="$(Get-Content -Raw caminho\conta-servico.json)" `
  WEBHOOK_SECRET="SEGREDO_GERADO"
```

Não cole os valores em mensagens, documentos ou commits.

## 4. Database Webhook

> Este passo já foi substituído pela trigger `trg_conexa_push_webhook`, que usa
> `pg_net` + Vault. O procedimento abaixo fica como alternativa/manual.

No painel do Supabase:

1. Integrations → Webhooks → Create a new hook.
2. Nome: `notify-push`.
3. Tabela: `public.notifications`.
4. Evento: `INSERT`.
5. Tipo: HTTP Request.
6. Método: POST.
7. URL:
   `https://lgsyuusotabxrjqgyqdq.supabase.co/functions/v1/send-push`
8. Header:
   `x-webhook-secret: <mesmo WEBHOOK_SECRET>`
9. Salve e faça um teste de inserção em `notifications` para uma conta de teste.

A Edge Function já foi publicada com `--no-verify-jwt`; a autenticação é feita pelo segredo do webhook.

## 5. Retry automático

O workflow `.github/workflows/notification-retry.yml` roda a cada 10 minutos.

No GitHub do repositório, configure os secrets:

- `NOTIFICATION_FUNCTION_URL`:
  `https://lgsyuusotabxrjqgyqdq.supabase.co/functions/v1/send-push`
- `NOTIFICATION_WEBHOOK_SECRET`: o mesmo `WEBHOOK_SECRET`.

Se os secrets não existirem, o workflow apenas ignora a execução.

## 6. Teste mínimo

Com duas contas de teste:

1. Conta A envia pedido de mensagem para B.
2. B recebe push “Novo pedido de mensagem” e item na central.
3. B aceita; A recebe “Conexão aceita”.
4. Em conversa aceita, A envia mensagem; B recebe apenas “Nova mensagem”.
5. A central mostra o item; toque abre a conversa correta.
6. Aprovar/rejeitar material notifica o autor; material pendente notifica admins.
7. Desligar uma categoria não gera push nem item na central.
8. Logout e login com outra conta no mesmo aparelho não mistura notificações.
9. App fechado e em segundo plano abrem a rota correta.
10. Token inválido é removido no envio.

## 7. Diagnóstico

No app:

- Administração → ícone de notificações.
- Mostra pendentes, enviadas, com erro, tokens mascarados, último uso e falhas recentes.

No Supabase:

- Table Editor → `notifications`: fila e histórico.
- Table Editor → `device_tokens`: token completo apenas para diagnóstico administrativo.
- Edge Functions → `send-push` → Logs: erros de OAuth/FCM, sem conteúdo de mensagem.

## 8. Runbook de falhas

### Push não chega

1. A central tem o item?
   - Não: gatilho/preferência não gerou. Verifique `notifications` e `notification_preferences`.
   - Sim: o problema é envio.
2. `pushed_at` está preenchido?
   - Sim: FCM aceitou; verificar permissão, economia de bateria e token do aparelho.
   - Não: verificar `FCM_SERVICE_ACCOUNT`, webhook e logs da função.
3. O webhook foi chamado?
   - Verifique Integrations → Webhooks e os logs.
4. O cron rodou?
   - Verifique Actions → Notification retry.
5. Token do aparelho existe?
   - O usuário abriu o app e permitiu notificações? `device_tokens`.
6. Conta de serviço sem permissão?
   - Revise o papel e a chave.

### Erro de OAuth/FCM

- Conferir `client_email`, `private_key`, `project_id` no segredo.
- Conferir se a API do FCM está ativa.
- Verificar rotação/revogação da chave.

### Notificação para a pessoa errada

- Verificar limpeza de token no logout.
- O app registra o token para o usuário atual; um login novo reassocia o mesmo token.
- Se persistir, remover o token em `device_tokens` e testar novamente.

### Duplicidade

- A fila usa `pushed_at`; o retry não deve reenviar já enviados.
- Verificar se dois webhooks estão configurados.
- Verificar se o app está mostrando notificação local além da notificação do sistema.

## 9. Privacidade

- Push de mensagem: apenas “Nova mensagem”.
- Sem remetente, conteúdo, email, gênero ou dados de estudo no payload.
- Dados levam apenas IDs de rota.
- A central mostra detalhes leves; conteúdo de mensagem não.
- Tokens completos não aparecem no app admin.
- Logs sem PII e sem token completo.

## Checklist

- [x] API do FCM ativa.
- [x] Conta de serviço com papel mínimo.
- [x] JSON no segredo do Supabase.
- [x] `WEBHOOK_SECRET` no Supabase.
- [x] Webhook de `notifications` INSERT configurado via pg_net/Vault.
- [x] Secrets do GitHub para retry.
- [ ] Workflow de retry commitado/publicado no GitHub.
- [ ] Teste das quatro categorias em aparelho real.
- [ ] Teste de permissão negada.
- [ ] Teste de logout/troca de conta.
- [ ] Teste de app fechado.
- [ ] Diagnóstico admin conferido com dados reais.
- [ ] Rotação programada.
