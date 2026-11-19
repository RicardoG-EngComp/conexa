# Releases e distribuição

Registro das versões enviadas ao **Firebase App Distribution** (testadores usam
o App Tester). Versões anteriores à 1.0.15 não tinham registro neste arquivo;
o histórico completo fica no Console do Firebase.

## 1.1.0+25 — Novo hub, busca, mapa e pessoas

- **Data:** 19 de novembro de 2026.
- **Versão:** `1.1.0` (versionCode `25`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **Grupo:** `ufv-beta` — UFV Beta.
- **Banco:** migrations `20261124140000_p7_hub` e `20261124141000_p7_campus_delete`.
- **Distribuição:** Firebase App Distribution.

### O que entrou

- Hub com Feed, Buscar, Mapa, Notificações e Chat.
- Avatar no topo esquerdo com menu de perfil, conexões, assinatura, grupos e ajustes.
- Pessoas no ícone de pessoa+ com busca, pedidos e sugestões.
- Busca acadêmica por disciplina, tema, material, pergunta e professor.
- Letreiro de eventos com link externo; sem comissão nesta fase.
- Mapa OpenStreetMap com sugestões de locais e aprovação de admin.
- Notificações sem mensagens e com abas Tudo/Menções.
- Ícones Ribbon Line próprios.

### Notas usadas no App Distribution

```text
Novo hub com Buscar, Mapa, Notificacoes e Chat.
Busca academica, pessoas/conexoes, eventos e mapa colaborativo.
Mensagens agora ficam no Chat; notificacoes sao de posts, mencoes e solicitacoes.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.1.0 --build-number=25
```

## 1.0.20+24 — Ajustes visuais das skins

- **Data:** 18 de novembro de 2026.
- **Versão:** `1.0.20` (versionCode `24`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **APK:** universal, 72.025.104 bytes.
- **SHA-256:** `C1606019169E162225413781BAD06A11D78A09DB393C197BF9F0E0F88E9B745C`.
- **Grupo:** `ufv-beta` — UFV Beta.
- **Distribuição:** Firebase App Distribution.
- **Console:** https://console.firebase.google.com/project/conexa-20a9b/appdistribution/app/android:com.ricardogengcomp.conexa/releases/532kl5h2fb8s8
- **Testadores:** https://appdistribution.firebase.google.com/testerapps/1:4747139353:android:fdd0d000d5a7803aafcd88/releases/532kl5h2fb8s8

### O que entrou

- Meia-noite & Coral: fundo preto.
- Café, Ocre & Champagne: fundo champagne.
- Branco & Vinho: fundo branco.
- Pêssego & Granito: fundo granito.
- Removidas: Uva & Ouro, Turquesa & Rosa, Floresta & Brasa e Gelo & Rubi.
- Catálogo final: 37 skins.

### Notas usadas no App Distribution

```text
Ajustes visuais nas skins e remocao de quatro paletas.
Agora sao 37 skins em Ajustes > Aparencia.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.20 --build-number=24
```

## 1.0.19+23 — Gestão, notificações e skins

- **Data:** 18 de novembro de 2026.
- **Versão:** `1.0.19` (versionCode `23`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **APK:** universal, 72.025.108 bytes.
- **SHA-256:** `5070A4B1E61360BD03A2E83AA89A8BD1C5374DFCF180E820D29E1F4EEDCEFCB5`.
- **Grupo:** `ufv-beta` — UFV Beta.
- **Banco:** migrations `20261124130000_group_governance` e `20261124131000_notification_per_conversation`.
- **Distribuição:** Firebase App Distribution.
- **Console:** https://console.firebase.google.com/project/conexa-20a9b/appdistribution/app/android:com.ricardogengcomp.conexa/releases/1hrl7f2nv4gng
- **Testadores:** https://appdistribution.firebase.google.com/testerapps/1:4747139353:android:fdd0d000d5a7803aafcd88/releases/1hrl7f2nv4gng

### O que entrou

- Cargo de gestão transferível.
- “Administração” com vários administradores em Centro Acadêmico, República e Diretório Acadêmico.
- Criador recebe todos os privilégios; permissões agora vêm somente dos cargos.
- Remoção do antigo gestor após a transferência.
- Notificação única por conversa, com total de mensagens não lidas.
- 41 skins com contraste validado e seleção em Ajustes → Aparência.

### Notas usadas no App Distribution

```text
Grupos com gestão transferível e administradores múltiplos.
Mensagens do mesmo chat agora aparecem em uma única notificação com contador.
Novas skins para personalizar as cores do app em Ajustes > Aparência.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.19 --build-number=23
```

## 1.0.18+22 — Correções de chat e notificações

- **Data:** 18 de novembro de 2026.
- **Versão:** `1.0.18` (versionCode `22`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **APK:** universal, 71.992.188 bytes.
- **SHA-256:** `AD0BC4D97CDCE70A0B3122AC18A071E67D8B55CCFFA4CBC055C33280C6B96AD3`.
- **Grupo:** `ufv-beta` — UFV Beta.
- **Banco:** migration `20261124120000_fix_group_chat_notifications`.
- **Distribuição:** Firebase App Distribution.
- **Console:** https://console.firebase.google.com/project/conexa-20a9b/appdistribution/app/android:com.ricardogengcomp.conexa/releases/0q54qceqmm0ag
- **Testadores:** https://appdistribution.firebase.google.com/testerapps/1:4747139353:android:fdd0d000d5a7803aafcd88/releases/0q54qceqmm0ag

### O que entrou

- Chat do grupo abre com o nome do grupo, não com o nome de um participante.
- Textos “Público” e “Você” corrigidos.
- Notificações de mensagens agrupadas por remetente, com contador
  (“Carlos — 10 novas mensagens”) e nome do remetente.
- Tela de material pendente ganhou voltar, inclusive ao abrir pela notificação.

### Notas usadas no App Distribution

```text
Correções no chat do grupo, nos textos e nas notificações.
Mensagens do mesmo remetente agora aparecem em um único bloco com contador.
A tela de material pendente voltou a ter seta de voltar.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.18 --build-number=22
```

## 1.0.17+21 — Hardening P5

- **Data:** 17 de novembro de 2026.
- **Versão:** `1.0.17` (versionCode `21`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **Grupo:** `ufv-beta` — UFV Beta.
- **Banco:** migrations P5 aplicadas no Supabase.
- **Distribuição:** Firebase App Distribution.

### O que entrou

- 2FA removido; login segue pela conta institucional.
- Upload de vídeo desativado no MVP por custo; feed e chat seguem com imagem/PDF.
- Exportação dos próprios dados em arquivo.
- Termos de moderação administráveis pelo admin.
- Mídia em posts agendados/rascunhos.
- Adicionar/remover membros no chat de grupo.
- RSVP e lembretes de eventos.
- Busca em comentários e busca de perguntas no Q&A.
- Anexos de imagem/PDF no Q&A.
- Contagem de views e painel de insights.
- Comentário público nas avaliações de materiais.
- Posts ocultos com opção de desfazer.

### Notas usadas no App Distribution

```text
Feed, chat, grupos e estudos mais completos.
Agora com mídia agendada, membros no chat, RSVP, anexos no Q&A,
busca em comentários, views e avaliações com comentário.
2FA e upload de vídeo foram removidos nesta versão.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.17 --build-number=21
```

## 1.0.16+20 — Mídia rápida no R2

- **Data:** 13 de novembro de 2026.
- **Versão:** `1.0.16` (versionCode `20`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **APK:** universal, 65,4 MB.
- **SHA-256:** `5A86482AB53E2C4F20DD008925BAF0C7392AEF27D191A51998539A56C58789BF`.
- **Grupo:** `ufv-beta` — UFV Beta (3 testadores).
- **Banco:** migration `20261117120000_media_objects` aplicada no Supabase.
- **Distribuição:** Firebase App Distribution.

### O que entrou

- Fotos de perfil e materiais de estudo agora usam Cloudflare R2 privado.
- Upload em WebP: foto cheia 1280px e miniatura 480px; avatar 512px e 160px.
- Compressão no aparelho em isolate, com orientação corrigida e EXIF removido.
- Cache em disco de 500 objetos/30 dias, limpo no logout.
- Feed com lista preguiçosa e imagens decodificadas no tamanho exibido.
- Fotos antigas do Supabase continuam funcionando via fallback.
- Estudos antigos e novos continuam abrindo via `study-file-url` com fallback.
- Estrutura de backup diário do R2 com retenção de 7 dias.
  - Requer o bucket `conexa-backup` e o token de backup configurados.

### Notas usadas no App Distribution

```text
Midia mais rapida e leve: fotos em WebP, miniaturas e cache.
Fotos e materiais novos usam armazenamento R2 privado.
Fotos e PDFs antigos continuam funcionando.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.16 --build-number=20
```

### Como distribuir (manual)

Com o Firebase CLI autenticado na conta do projeto:

```powershell
npx -y firebase-tools appdistribution:distribute "app/build/app/outputs/flutter-apk/app-release.apk" `
  --app "1:4747139353:android:fdd0d000d5a7803aafcd88" `
  --project conexa-20a9b `
  --groups ufv-beta `
  --release-notes "Midia mais rapida e leve: fotos em WebP, miniaturas e cache. Fotos e materiais novos usam armazenamento R2 privado. Fotos e PDFs antigos continuam funcionando."
```

### Links úteis

- Console: https://console.firebase.google.com/project/conexa-20a9b/appdistribution/app/android:com.ricardogengcomp.conexa/releases/5u3nntg0nt900
- Testadores: https://appdistribution.firebase.google.com/testerapps/1:4747139353:android:fdd0d000d5a7803aafcd88/releases/5u3nntg0nt900

### Rollback

Reenvie o APK `1.0.15+19` ao mesmo grupo. O backend mantém fallback para
fotos e PDFs antigos no Supabase Storage.

---

## 1.0.15+19 — Canal de feedback

- **Data:** 13 de novembro de 2026.
- **Versão:** `1.0.15` (versionCode `19`).
- **Pacote:** `com.ricardogengcomp.conexa`.
- **APK:** universal, 63,8 MB.
- **SHA-256:** `ECD22EDD4F73BBB663CC5F694B32BDD16D2E13AA0C21053ECDAA95CB4C5999C5`.
- **Grupo:** `ufv-beta` — UFV Beta (3 testadores).
- **Banco:** migration `20261116120000_feedback` aplicada no Supabase.
- **Distribuição:** manual via Firebase CLI, autenticado como a conta do projeto.

### O que entrou

- Canal de feedback no app: relato de bug e envio de sugestão.
- Print opcional no bug, em bucket privado.
- Protocolo (`BUG-000123` / `SUG-000045`) e acompanhamento em “Meus envios”.
- Tela administrativa de feedback, com filtros, detalhe e mudança de status.
- Limite de 20 envios por dia por tipo, aplicado no servidor.
- Script de exportação para `feedback/Bugs.md` e `feedback/Sugestoes.md`.
- Três agentes do opencode: triagem de bugs, revisão de sugestões e implementação.

### Notas usadas no App Distribution

```text
Canal de feedback: reporte bugs e envie sugestoes pelo app.
Anexo opcional de print nos bugs.
Administradores podem triar e mudar o status em Administracao > Feedback.
```

### Como reproduzir o build

```powershell
cd app
flutter build apk --release --build-name=1.0.15 --build-number=19
```

### Como distribuir (manual)

Com o Firebase CLI autenticado na conta do projeto:

```powershell
firebase appdistribution:distribute "app/build/app/outputs/flutter-apk/app-release.apk" `
  --app "1:4747139353:android:fdd0d000d5a7803aafcd88" `
  --project conexa-20a9b `
  --groups ufv-beta `
  --release-notes "Canal de feedback: reporte bugs e envie sugestoes pelo app. Anexo opcional de print nos bugs. Administradores podem triar e mudar o status em Administracao > Feedback."
```

Links úteis:

- Console: https://console.firebase.google.com/project/conexa-20a9b/appdistribution/app/android:com.ricardogengcomp.conexa/releases/0s61292pamdn8
- Testadores: https://appdistribution.firebase.google.com/testerapps/1:4747139353:android:fdd0d000d5a7803aafcd88/releases/0s61292pamdn8

### Rollback

O banco é compatível com o app antigo. Se precisar voltar, reenvie o APK da
build anterior (1.0.14, build 18) ao mesmo grupo; o App Distribution mantém o
histórico de releases.
