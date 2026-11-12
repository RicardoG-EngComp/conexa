# Escopo do MVP

## Princípios
- **18+ exclusivo** com verificação de idade antes do acesso.
- **Privacidade por padrão**: sem venda ou compartilhamento de dados.
- **Dados mínimos**: coletar apenas o necessário.
- **Custo baixo**: usar serviços gratuitos/open-source no MVP.

## Público
Jovens, casais e pessoas LGBT (maiores de 18 anos) que buscam interação
amigável ou sexual.

## Funcionalidades do MVP

### 1. Cadastro e verificação (18+)
- E-mail/telefone + senha.
- Consentimentos granulares e versionados.
- Verificação de identidade (ver `FLUXO-VERIFICACAO.md`).
- Conta só é liberada após aprovação.

### 2. Perfil
- Fotos, bio, interesses e preferências.
- Controles de visibilidade.
- Exclusão de conta e de dados.

### 3. Descoberta e conexões
- Feed de perfis por afinidade.
- Ação de curtir/descartar e conexão mútua.
- Filtros básicos gratuitos; filtros avançados na assinatura.

### 4. Chat
- Mensagens entre conexões.
- Proteção antissedilidade para não-conexões.
- Denúncia e bloqueio imediatos.
- Moderação com IA no dispositivo + revisão humana.

### 5. Localização (opcional)
- Opt-in explícito, separado do uso do app.
- Localização **grosseira** (área/bairro), nunca precisa por padrão.
- Registro de "encontro" com retenção curta (ex.: 30 dias).
- Exibir apenas **área aproximada**, nunca o ponto exato do outro usuário.
- Possibilidade de desligar a qualquer momento.

### 6. Assinatura
- Pix manual, mensal ou anual.
- Programa de indicação: 3 amigos assinantes → R$ 5/mês cada.
- Regras claras de cobrança, cancelamento e reembolso (CDC).

### 7. Assistente de IA (on-device)
- Ajuda a iniciar conversas.
- Moderação de linguagem ofensiva.
- Processamento no aparelho; sem envio de mensagens a terceiros.

### 8. Painel do titular
- Acesso, correção, exclusão, portabilidade e revogação de consentimento.

## Fora do escopo do MVP
- Venda de fotos ou conteúdo sexual entre usuários.
- Anúncios/publicidade.
- Compartilhamento de dados com terceiros para marketing.
- Recorrência automática de pagamento.

## Arquitetura técnica (proposta)
| Camada | Opção inicial (custo zero) |
|---|---|
| App | React Native/Expo ou Flutter |
| Backend/DB/Auth | Supabase (free tier) |
| Armazenamento de mídia | Supabase Storage / Cloudflare R2 |
| Hospedagem de API | Cloudflare Workers / Render free |
| IA local | Modelo pequeno on-device (Gemma/Phi quantizado) |
| Pagamento | Asaas/Mercado Pago (Pix) |
| TLS/Domínio | Let's Encrypt + subdomínio gratuito |

> Free tiers servem para MVP/teste. Produção em escala tem custo real.

## Fluxo de dados (alto nível)
```
App -> API (auth, perfis, conexões, chat)
    -> Postgres (dados pseudonimizados)
    -> Storage de mídia (criptografado)
    -> IA on-device (liveness, moderação, assistente)
    -> PSP (Pix)  |  Validação local do QR da CIN/CNH
```
Nenhum dado é enviado para adtech ou venda.

## Requisitos não funcionais
- Criptografia em trânsito (TLS) e em repouso.
- Pseudonimização de identificadores.
- Controle de acesso por papel e logs de auditoria.
- Retenção e exclusão automáticas.
- Plano de resposta a incidentes.

## Fases
1. Definição de produto e regras.
2. Conformidade base (políticas, DPO, ROPA, DPIA).
3. MVP técnico com privacy-by-design.
4. Revisão jurídica pontual.
5. Beta fechado e lançamento.
