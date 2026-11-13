# Releases e distribuição

Registro das versões enviadas ao **Firebase App Distribution** (testadores usam
o App Tester). Versões anteriores à 1.0.15 não tinham registro neste arquivo;
o histórico completo fica no Console do Firebase.

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
