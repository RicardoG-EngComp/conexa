# Tinder de Republicas (nome provisório)

> ⚠️ **Nome provisório.** "Tinder de Republicas" é apenas o codinome de trabalho.
> O nome definitivo do produto ainda não foi escolhido.

Aplicativo **exclusivo para maiores de 18 anos** de matchmaking e interação entre
pessoas. O objetivo é oferecer um espaço para jovens, casais e pessoas LGBT
encontrarem outras pessoas para interagir — de forma **amigável ou sexual**.

## Problema
Encontrar pessoas com afinidade real é um processo fragmentado, informal e
inseguro. Os apps existentes priorizam volume, expõem dados e não oferecem
controles claros de segurança e privacidade.

## Proposta
- Match por afinidade e preferências.
- Chat com moderação e proteção contra assédio.
- Verificação de idade robusta (**18+**).
- Privacidade por padrão: **nenhum dado vendido ou compartilhado para publicidade**.

## Modelo de negócio
- Uso **gratuito**.
- Assinatura **opcional** que libera filtros avançados:
  - **R$ 10/mês** (ou plano anual com desconto).
  - **R$ 5/mês** no programa de indicação ("traga 3 amigos que assinem").
- Receita **100% de assinaturas**. Sem anúncios e sem venda de dados.

## Escopo do MVP
1. Cadastro 18+ com verificação de identidade.
2. Perfil, fotos, preferências e consentimentos.
3. Descoberta e match.
4. Chat com moderação e denúncia.
5. Localização opcional (aproximada, retenção curta).
6. Assinatura via Pix (manual, mensal/anual).
7. Assistente de IA **no dispositivo**.

Detalhes em [`docs/ESCOPO-MVP.md`](docs/ESCOPO-MVP.md).

## Conformidade
Este projeto trata **dados sensíveis** (incluindo vida sexual e biometria) e
conteúdo adulto. A conformidade com a **LGPD**, o **ECA Digital** e o **CDC** é
parte do escopo, não um extra.

- Checklist: [`docs/CONFORMIDADE-LGPD.md`](docs/CONFORMIDADE-LGPD.md)
- Verificação de idade: [`docs/FLUXO-VERIFICACAO.md`](docs/FLUXO-VERIFICACAO.md)

> ⚠️ **Aviso:** este repositório é um planejamento de produto. Não é
> aconselhamento jurídico. Antes do lançamento, é necessária revisão por
> profissional de direito especializado em LGPD.

## Documentos
| Documento | Descrição |
|---|---|
| [ROADMAP-BLOCOS](docs/ROADMAP-BLOCOS.md) | Construção organizada em blocos |
| [MAPA-DE-TELAS](docs/MAPA-DE-TELAS.md) | Telas e wireframes |
| [ESCOPO-MVP](docs/ESCOPO-MVP.md) | Escopo funcional e técnico do MVP |
| [FLUXO-VERIFICACAO](docs/FLUXO-VERIFICACAO.md) | Verificação de idade e identidade |
| [CONFORMIDADE-LGPD](docs/CONFORMIDADE-LGPD.md) | Checklist de conformidade |
| [POLITICA-PRIVACIDADE](docs/POLITICA-PRIVACIDADE.md) | Rascunho de política de privacidade |
| [TERMOS-DE-USO](docs/TERMOS-DE-USO.md) | Rascunho de termos de uso |

## Desenvolvimento (app Flutter)
O código fica em `app/`. Requisitos: Flutter 3.47.9+.

```powershell
cd app
flutter pub get
flutter run -d chrome    # preview no navegador
flutter run -d android   # emulador/dispositivo Android
flutter analyze
flutter test
```

## Autenticacao (Supabase)
O app usa **Supabase** (Auth + Postgres + RLS).

1. Copie `app/.env.example` para `app/.env`.
2. Preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY` (publishable key).
3. As migrations ficam em `supabase/migrations/`.

> `.env` nunca vai para o Git. A `service_role` nunca vai no app.

## Status
Ideia em validação. Objetivo: converter em produto.
- B0 (fundação) ✅
- B1.1 (auth Supabase) ✅
- B1.2 (identidade UFV por e-mail) ✅
- B2 (perfil + onboarding) ✅
- B3 (feed social) ✅
- B4 (chat + moderação) ✅
- B9 (admin + denúncias) ✅
- Próximo: matchmaking (Descobrir), AI Coach/assinatura e polimento visual.
