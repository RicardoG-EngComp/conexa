# Fluxo de verificação de idade e identidade (custo zero)

Objetivo: garantir que **somente maiores de 18 anos** acessem a plataforma,
usando ferramentas gratuitas e processamento **no dispositivo** do usuário.

> ⚠️ Nenhuma verificação é 100% infalível. O que protege juridicamente é adotar
> **medidas razoáveis, documentadas e auditáveis**.

## Visão geral
```
1. Consentimento
2. Captura do documento (frente + QR)
3. Validação do QR (servidor)
4. Prova de vida / liveness (on-device)
5. Face match documento <-> selfie (on-device)
6. Decisão + descarte dos dados brutos
7. Antifraude e re-verificação
```

## 1. Consentimento
- Consentimentos **granulares e versionados**.
- Consentimento de **biometria** separado e destacado (LGPD Art. 11).
- Registrar data, versão do termo e IP.

## 2. Captura do documento
- **Frente da CIN** (com foto) e **verso com QR**; ou **CNH** (com QR).
- Checagem de qualidade no aparelho: foco, brilho, enquadramento, reflexo.
- Bibliotecas: ML Kit (Google) ou OpenCV.

## 3. Validação do QR (servidor)
- Decodificar o QR: `zbar` / `pyzbar` / `zxing`.
- **CIN**: o QR é um **JWT assinado (ES512 / curva P-521)** emitido pelo MJSP.
  - Validar assinatura com a **chave pública JWK do MJSP**.
  - Checar `iss == "MJSP"` e presença de `url`.
  - Extrair `cpf`, `dns` (data de nascimento) e `dvd` (validade).
- **CNH**: decodificar o QR localmente.
  - A validação em base oficial (Datavalid) é paga; registrar essa limitação.
- Calcular idade pela data de nascimento → **exigir ≥ 18**.
- Guardar apenas `hash(salt + CPF)` para deduplicação; **nunca o CPF puro**.

## 4. Prova de vida (on-device)
- Selfie em vídeo curto ou sequência de frames.
- Liveness open-source: MediaPipe Face Mesh + antisspoofing
  (ex.: Silent-Face-Anti-Spoofing).
- Detecta foto de foto, tela, vídeo e deepfakes simples.
- Saída: **score de vivacidade** + **embedding facial**.

## 5. Face match (on-device)
- Detectar rosto na **foto do documento** (RetinaFace/OpenCV).
- Comparar com a selfie via **InsightFace/ArcFace** → similaridade.
- Abaixo do limiar → **revisão manual** ou bloqueio.

## 6. Decisão e descarte
- Tudo aprovado → conta **verificada 18+**.
- Falha → fila de revisão manual (humano) ou rejeição.
- **Excluir documento e selfie** após a validação (retenção curta).
- Manter apenas **log de auditoria** (data, scores, decisão), sem biometria bruta.

## 7. Antifraude e re-verificação
- Limite de tentativas e detecção de abuso.
- Detecção de **CPF duplicado** via hash.
- Denúncia "parece menor" → suspensão + re-verificação.
- Re-verificação periódica por amostragem.

## Bibliotecas gratuitas
| Função | Biblioteca |
|---|---|
| QR code | zbar / pyzbar / zxing |
| JWT ES512 | jose / jsonwebtoken |
| Detecção facial | MediaPipe / OpenCV / RetinaFace |
| Reconhecimento facial | InsightFace (ArcFace) |
| Liveness | MediaPipe + Silent-Face-Anti-Spoofing |
| OCR (se necessário) | Tesseract / PaddleOCR |
| Mobile ML | ML Kit / TensorFlow Lite |

## Limitações e riscos
- QR da CIN **não traz nome nem foto**; prova autenticidade e data de nascimento.
  A ligação com a pessoa depende de **liveness + face match**.
- Validação **no cliente** pode ser adulterada (aparelho rooteado). Por isso o
  servidor valida a assinatura do QR e aplica regras de risco.
- **Cobertura**: a CIN ainda está em rollout; RG antigo vale até 2032. Prever
  fallback (CNH com QR ou revisão manual).
- Verificação caseira é **medida razoável**, não garantia absoluta.

## Implementacao atual (B1.2)
- Captura de **frente**, **verso (QR)** e **selfie** (camera no Android; upload no web).
- QR da CIN decodificado no app (`zxing2`) e validado na **Edge Function `verify-cin`**
  (JWT **ES512**, chave publica do MJSP).
- Imagens enviadas ao bucket **privado** `verification-docs` (RLS por usuario).
- Revisao **manual** pelo dashboard do Supabase.
- Retencao: apagar imagens apos a revisao (maximo 7 dias).

### Revisao manual (admin)
1. Abra **Storage → verification-docs → `<user_id>/`** e confira documento x selfie.
2. Aprovar:
```sql
update public.verification_attempts
set status = 'approved', reviewed_at = now()
where id = '<attempt_id>';

update public.profiles
set verification_status = 'verified'
where id = '<user_id>';
```
3. Rejeitar: use `status = 'rejected'` e `verification_status = 'rejected'`.
4. Apague a pasta do usuario no Storage apos a revisao.

## Privacidade
- Processar biometria **no dispositivo** sempre que possível.
- Não armazenar templates biométricos nem imagens de documento.
- Documentar o fluxo na **DPIA**.
