# Roadmap em Blocos

## Decisões técnicas
| Tema | Decisão |
|---|---|
| Plataforma | **Android primeiro**; arquitetura já preparada para iOS |
| Framework | **Flutter** (código único Android/iOS, UI própria consistente) |
| Backend | Supabase (free tier) para auth, Postgres, storage |
| IA | **On-device** (LiteRT-LM + Gemma 3 1B / Gemma-3n E2B) |
| Mapa | **OpenFreeMap + MapLibre** (sem chave/limite); geocoding via Nominatim |
| Contas de casal | **Duas contas vinculadas** (estilo Instagram) |
| AI Coach | **Exclusivo para assinantes** |
| Conteúdo adulto explícito | **Fora do escopo** |
| Receita | Assinatura Pix (R$ 10/mês; R$ 5 no programa de indicação) |

## Revisão sobre o mapa
A licença do Maptoolkit proíbe "Adult Content". Como o app **não terá conteúdo
adulto explícito**, essa restrição **não é bloqueio automático**. Ainda assim,
mantemos **OpenFreeMap** como escolha principal por não ter limite de requisições
e não exigir chave. Se o Maptoolkit for usado, confirmar a definição de "Adult
Content" na licença e manter a atribuição.

## Blocos

### B0 — Fundação
**Entrega:** projeto Flutter, navegação, design tokens, tema, estrutura de pastas,
CI básico, documentos de conformidade.
**Pronto quando:** app abre vazio com tema e rotas funcionando.
**Status:** ✅ concluído (Flutter 3.47.9, Riverpod, go_router, tema e rotas).

### B1 — Identidade 18+
**Entrega:** cadastro, consentimentos, verificação de documento + liveness.
**Depende de:** B0.
**Pronto quando:** só entra quem passa no 18+ e o fluxo registra auditoria.
**Detalhe:** ver `FLUXO-VERIFICACAO.md`.

### B2 — Perfil & Onboarding
**Entrega:** fotos, prompts, interesses, estilo de relação
(monogamia/não-monogamia/casal), preferências, **vinculação de contas de casal**.
**Depende de:** B1.
**Pronto quando:** perfil completo, editável e com parceiro vinculado.

### B3 — Descoberta & Match
**Entrega:** feed de perfis, curtir/comentar, match mútuo.
**Depende de:** B2.
**Pronto quando:** match acontece ponta a ponta.

### B4 — Chat & Segurança
**Entrega:** mensagens, filtro antissedilidade, denúncia e bloqueio.
**Depende de:** B3.
**Pronto quando:** chat funciona com alertas e denúncia.

### B5 — AI Coach (assinante)
**Entrega:** dicas de foto, sugestões de conversa, análise de perfil.
**Depende de:** B4.
**Pronto quando:** assinante recebe dicas no dispositivo.

### B6 — Localização & Mapa
**Entrega:** opt-in, área aproximada, mapa, "perto de você".
**Depende de:** B2/B3.
**Pronto quando:** descoberta por proximidade funciona.

### B7 — Assinatura Pix
**Entrega:** planos R$10/R$5, programa de indicação, cancelamento.
**Depende de:** B3.
**Pronto quando:** cobrança e liberação de acesso funcionam.

### B8 — Confiança & Denúncia
**Entrega:** fila de denúncias, SLA, orientação policial, denúncia de uso de
imagem sem consentimento.
**Depende de:** B4.
**Pronto quando:** denúncia é tratada e registrada.

### B9 — Admin/Moderação
**Entrega:** painel web de moderação, gestão de usuários e denúncias.
**Depende de:** B4/B8.
**Pronto quando:** time consegue moderar sem acesso direto ao banco.

### B10 — Beta & Lançamento
**Entrega:** teste fechado, telemetria mínima, ajustes.
**Depende de:** todos.
**Pronto quando:** beta roda com monitoramento.

## Contas de casal (duas contas vinculadas)
- Cada pessoa tem **sua própria conta e verificação**.
- A vinculação exige **consentimento dos dois** (registro de aceite).
- O perfil pode exibir **"relaciona-se com @parceiro"** e **anexar o perfil do
  parceiro** (com autorização).
- Denúncia: "perfil usando imagem de alguém sem consentimento" → revisão humana.

## Direção visual (aprovada)
- Papel `#F6F2EA`, tinta `#14130F`, acento verde-petróleo `#0F5C5C`.
- Tipografia: **Newsreader** (títulos/prompts) + **IBM Plex Sans** (corpo).
- Muito espaço em branco, cards de prompt grandes, grade assimétrica.
- Referência de **clima** do Hinge, **sem copiar** layouts/assets.

## Riscos
- Verificação caseira é medida razoável, não garantia absoluta.
- IA de 1–2B tem limites; revisão humana continua necessária.
- Free tiers servem para MVP; escala tem custo.
- Sem CNPJ, a monetização e a responsabilidade ficam limitadas/pessoais.
