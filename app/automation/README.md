# Automação de emulador Android para testes do Conexa

## Pré-requisitos

- Android SDK instalado em `%LOCALAPPDATA%\Android\Sdk`
- Java/JDK disponível
- Sistema image `android-35` (o script `create-avd.ps1` instala se faltar)

## Scripts

| Script | O que faz |
|---|---|
| `create-avd.ps1` | Cria AVD do zero. Sistema image pixel_5 android-35. |
| `start-emulator.ps1` | Inicia emulador headless e aguarda boot completo. |
| `install-apk.ps1` | Instala APK release via adb. |
| `grant-revoke-notification-permission.ps1` | Concede ou revoga `POST_NOTIFICATIONS`. |
| `force-stop.ps1` | Mata o processo do app. |
| `open-app.ps1` | Abre o app no emulador. |
| `capture-screenshot.ps1` | Screenshots como evidência. |
| `run-notification-flow.ps1` | Orquestra os passos de teste de push. |

## Uso básico

```powershell
# 1. Criar AVD (uma vez)
powershell -File app\automation\create-avd.ps1

# 2. Iniciar emulador
powershell -File app\automation\start-emulator.ps1

# 3. Fluxo completo de push
powershell -File app\automation\run-notification-flow.ps1
```

## Variáveis de ambiente necessárias

Para injetar notificação via RPC, estas env devem estar configuradas:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `TEST_USER_A_EMAIL`
- `TEST_USER_A_PASSWORD`

Se não configuradas, o fluxo pula a injeção de push e apenas captura screenshot.

## Fluxo completo em ordem

1. `create-avd.ps1` — cria o AVD uma vez.
2. `start-emulator.ps1` — inicia o emulador.
3. `run-notification-flow.ps1` — instala APK, concede permissão, abre o app, injeta push, captura screenshot como evidência.

## Notas

- O emulador roda headless (sem tela visível).
- As capturas de screenshot são o mecanismo de evidência visual.
- O teste manual com aparelho físico continua sendo o passo final para validar percepção visual.
- Estes scripts rodam apenas localmente, não no CI.
