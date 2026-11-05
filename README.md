# Conexa (nome provisório)

> **Nome provisório.** O codinome anterior era "Tinder de Republicas"; o produto
> agora se chama **Conexa**. O nome definitivo ainda será validado.

O Conexa é a **comunidade universitária em um só lugar**: rede social, estudos e
vida do campus, começando pela UFV como case e depois expandindo para as
universidades federais.

- **18+** no Conexa Universitário.
- Verificação por email institucional.
- Estudos primeiro; romance fica para uma fase futura.
- **Sem anúncios e sem venda de dados.**
- Beta gratuito; planos pagos depois.

## Produtos

| Produto | Público | Idade | Núcleo |
|---|---|---|---|
| **Conexa Universitário** | Alunos, professores, servidores, alumni | 18+ | Social + estudos + campus |
| **Conexa Escola** | Ensino médio/ENEM | Menores, com proteção | Estudo + Q&A moderado (produto separado) |

## Status

- B0 (fundação) ✅
- B1.1 (auth Supabase) ✅
- B1.2 (identidade UFV por e-mail) ✅
- B2 (perfil + onboarding) ✅
- B3 (feed social + descobrir + conexões) ✅
- B4 (chat + moderação) ✅
- B9 (admin + denúncias) ✅
- Play Store / beta fechado: em preparação.
- Próximo: MVP de Estudos (10–20 disciplinas da UFV).

## Documentos

| Documento | Descrição |
|---|---|
| [BLUEPRINT-CONEXA](docs/BLUEPRINT-CONEXA.md) | Visão, produtos, papéis, receita, empregos e roadmap |
| [MODERACAO](docs/MODERACAO.md) | Política, denúncias, aplicação e integridade acadêmica |
| [PLAY-STORE-BETA](docs/PLAY-STORE-BETA.md) | Checklist da Play, ficha, data safety e testadores |
| [ESTUDOS-MVP](docs/ESTUDOS-MVP.md) | Escopo do MVP de estudos |
| [ROADMAP-BLOCOS](docs/ROADMAP-BLOCOS.md) | Construção organizada em blocos |
| [MAPA-DE-TELAS](docs/MAPA-DE-TELAS.md) | Telas e wireframes |
| [ESCOPO-MVP](docs/ESCOPO-MVP.md) | Escopo funcional e técnico |
| [FLUXO-VERIFICACAO](docs/FLUXO-VERIFICACAO.md) | Verificação de idade e identidade |
| [CONFORMIDADE-LGPD](docs/CONFORMIDADE-LGPD.md) | Checklist de conformidade |
| [POLITICA-PRIVACIDADE](docs/POLITICA-PRIVACIDADE.md) | Política de privacidade |
| [TERMOS-DE-USO](docs/TERMOS-DE-USO.md) | Termos de uso |

## Privacidade e moderação

- [Política de Privacidade pública](docs/privacy.html)
- [Termos de Uso públicos](docs/terms.html)
- [Diretrizes da Comunidade](docs/community-guidelines.html)
- [Excluir conta](docs/account-deletion.html)

Ativar GitHub Pages em **Settings > Pages**, pasta `/docs`, antes de submeter à
Play Store.

## Desenvolvimento (app Flutter)

O código fica em `app/`. Requisitos: Flutter 3.47.9+.

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d android
```

## Autenticação (Supabase)

1. Copie `app/.env.example` para `app/.env`.
2. Preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY` (publishable key).
3. As migrations ficam em `supabase/migrations/`.

> `.env` nunca vai para o Git. A `service_role` nunca vai no app.

## Princípios

> **JAMAIS escolheremos um caminho apenas por ser “mais simples”. Faremos apenas o que for melhor e mais seguro, respeitando os limites orçamentários do projeto (praticamente zero).**

Detalhes em [docs/PRINCIPIOS.md](docs/PRINCIPIOS.md).
