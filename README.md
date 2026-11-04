# Tinder de Republicas (nome provisÃ³rio)

> âš ï¸ **Nome provisÃ³rio.** "Tinder de Republicas" Ã© apenas o codinome de trabalho.
> O nome definitivo do produto ainda nÃ£o foi escolhido.

Aplicativo **exclusivo para maiores de 18 anos** de matchmaking e interaÃ§Ã£o entre
pessoas. O objetivo Ã© oferecer um espaÃ§o para jovens, casais e pessoas LGBT
encontrarem outras pessoas para interagir â€” de forma **amigÃ¡vel ou sexual**.

## Problema
Encontrar pessoas com afinidade real Ã© um processo fragmentado, informal e
inseguro. Os apps existentes priorizam volume, expÃµem dados e nÃ£o oferecem
controles claros de seguranÃ§a e privacidade.

## Proposta
- Match por afinidade e preferÃªncias.
- Chat com moderaÃ§Ã£o e proteÃ§Ã£o contra assÃ©dio.
- VerificaÃ§Ã£o de idade robusta (**18+**).
- Privacidade por padrÃ£o: **nenhum dado vendido ou compartilhado para publicidade**.

## Modelo de negÃ³cio
- Uso **gratuito**.
- Assinatura **opcional** que libera filtros avanÃ§ados:
  - **R$ 10/mÃªs** (ou plano anual com desconto).
  - **R$ 5/mÃªs** no programa de indicaÃ§Ã£o ("traga 3 amigos que assinem").
- Receita **100% de assinaturas**. Sem anÃºncios e sem venda de dados.

## Escopo do MVP
1. Cadastro 18+ com verificaÃ§Ã£o de identidade.
2. Perfil, fotos, preferÃªncias e consentimentos.
3. Descoberta e match.
4. Chat com moderaÃ§Ã£o e denÃºncia.
5. LocalizaÃ§Ã£o opcional (aproximada, retenÃ§Ã£o curta).
6. Assinatura via Pix (manual, mensal/anual).
7. Assistente de IA **no dispositivo**.

Detalhes em [`docs/ESCOPO-MVP.md`](docs/ESCOPO-MVP.md).

## Conformidade
Este projeto trata **dados sensÃ­veis** (incluindo vida sexual e biometria) e
conteÃºdo adulto. A conformidade com a **LGPD**, o **ECA Digital** e o **CDC** Ã©
parte do escopo, nÃ£o um extra.

- Checklist: [`docs/CONFORMIDADE-LGPD.md`](docs/CONFORMIDADE-LGPD.md)
- VerificaÃ§Ã£o de idade: [`docs/FLUXO-VERIFICACAO.md`](docs/FLUXO-VERIFICACAO.md)

> âš ï¸ **Aviso:** este repositÃ³rio Ã© um planejamento de produto. NÃ£o Ã©
> aconselhamento jurÃ­dico. Antes do lanÃ§amento, Ã© necessÃ¡ria revisÃ£o por
> profissional de direito especializado em LGPD.

## Documentos
| Documento | DescriÃ§Ã£o |
|---|---|
| [ROADMAP-BLOCOS](docs/ROADMAP-BLOCOS.md) | ConstruÃ§Ã£o organizada em blocos |
| [MAPA-DE-TELAS](docs/MAPA-DE-TELAS.md) | Telas e wireframes |
| [ESCOPO-MVP](docs/ESCOPO-MVP.md) | Escopo funcional e tÃ©cnico do MVP |
| [FLUXO-VERIFICACAO](docs/FLUXO-VERIFICACAO.md) | VerificaÃ§Ã£o de idade e identidade |
| [CONFORMIDADE-LGPD](docs/CONFORMIDADE-LGPD.md) | Checklist de conformidade |
| [POLITICA-PRIVACIDADE](docs/POLITICA-PRIVACIDADE.md) | Rascunho de polÃ­tica de privacidade |
| [TERMOS-DE-USO](docs/TERMOS-DE-USO.md) | Rascunho de termos de uso |

## Desenvolvimento (app Flutter)
O cÃ³digo fica em `app/`. Requisitos: Flutter 3.47.9+.

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

## Princípios
> **JAMAIS escolheremos um caminho apenas por ser “mais simples”. Faremos apenas o que for melhor e mais seguro, respeitando os limites orçamentários do projeto (praticamente zero).**

Detalhes em [docs/PRINCIPIOS.md](docs/PRINCIPIOS.md).

## Status
Ideia em validaÃ§Ã£o. Objetivo: converter em produto.
- B0 (fundaÃ§Ã£o) âœ…
- B1.1 (auth Supabase) âœ…
- B1.2 (identidade UFV por e-mail) âœ…
- B2 (perfil + onboarding) âœ…
- B3 (feed social) âœ…
- B4 (chat + moderaÃ§Ã£o) âœ…
- B9 (admin + denÃºncias) âœ…
- PrÃ³ximo: matchmaking (Descobrir), AI Coach/assinatura e polimento visual.

