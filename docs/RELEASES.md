# Releases e distribuição

Registro das versões enviadas ao **Firebase App Distribution** (testadores usam
o App Tester). Versões anteriores à 1.0.15 não tinham registro neste arquivo;
o histórico completo fica no Console do Firebase.

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
- Estrutura de backup do R2 com retenção de 7 dias.
  - Disparo manual até o bucket `conexa-backup` e o token de backup existirem.
  - O cron diário está pausado no workflow.

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
