# Play Store: Beta do Conexa

## Conta

1. Criar conta Google dedicada ao app (2FA).
2. Criar conta de desenvolvedor em `play.google.com/console`.
3. Pagar US$ 25 (uma vez).
4. Conta **pessoal**; verificacao de identidade (1 a 3 dias).
5. Aceitar o contrato de distribuicao.

## Trilhas

| Trilha | Uso | Limite |
|---|---|---|
| Teste interno | Equipe | 100 testadores |
| Teste fechado | Estudantes da UFV | 2.000 por lista |
| Producao | Publico | 12 testadores opt-in por 14 dias |

O teste interno nao conta para producao. O beta pode ter centenas de pessoas;
12 e o minimo para liberar a producao.

## App

- Nome de listagem: **Conexa**.
- Pacote: `com.ricardogengcomp.conexa` (fixo).
- Idioma: portugues (Brasil).
- Categoria: Social.
- Gratuito; sem anuncios.
- Publico-alvo 18+; **Restrict Minor Access** ativado.
- Assinatura: Play App Signing.
- `versionCode`: 19 (`1.0.15+19`) na build beta atual.
  O upload na Play ainda não foi feito; a distribuição do beta é pelo App
  Distribution (ver `docs/RELEASES.md`).

## Bloqueios antes do upload

- [ ] Remover `REQUEST_INSTALL_PACKAGES` e auto-update.
- [ ] Implementar exclusao de conta no app + link web.
- [ ] Publicar termos, privacidade e diretrizes.
- [ ] Criar conta de teste para o revisor.
- [ ] Remover permissoes de midia desnecessarias.
- [ ] Sem permissao de localizacao.
- [ ] Gerar AAB assinado.
- [ ] Preencher Data safety.
- [ ] Content rating 18+.
- [ ] App access com credenciais de teste.
- [ ] Desinstalar o APK manual do celular (assinatura diferente).

## Ficha da loja (rascunho)

**Nome:** Conexa

**Descricao curta:** A comunidade universitaria em um so lugar.

**Descricao completa:**
O Conexa e a rede da comunidade universitaria. Conecte-se com estudantes,
participe de grupos, acompanhe a vida do campus e estude com materiais e
duvidas da sua universidade. Ambiente 18+, com moderacao e diretrizes claras.

Beta fechado para estudantes da UFV.

**Contato:** `conexa.projeto@gmail.com`.

**Politica de privacidade:** `https://ricardog-engcomp.github.io/conexa/privacy.html`

**Exclusao de conta:** `https://ricardog-engcomp.github.io/conexa/account-deletion.html`

> Ativar GitHub Pages em Settings > Pages, pasta `/docs`, antes de submeter.

> **Build Play:** a build beta atual (1.0.15+19) inclui o SDK do Firebase App
> Distribution, que é exclusivo do beta. Antes de publicar na Play, remover o
> plugin `firebase_app_distribution`, o `google-services.json` e o serviço de
> update do beta; a Play usa In-App Updates. O SDK não adicionou permissões
> extras ao APK atual (somente INTERNET).

## Data safety (rascunho)

Coletado:
- Email, nome, data de nascimento.
- Curso, campus, bio, prompts.
- Fotos de perfil.
- Mensagens e conexoes.
- Denuncias e dados de uso/seguranca.
- Feedbacks (bugs e sugestoes) e prints opcionais.

Nao coletado no beta:
- Localizacao.
- Biometria.
- Dados financeiros.

Praticas:
- Criptografado em transito.
- Sem venda de dados.
- Exclusao de conta disponivel.
- Dados de moderacao retidos pelo tempo necessario a seguranca/obrigacao legal.

## App access (revisor)

Contas de teste ja criadas:

- `beta.reviewer@alunos.ufv.br`
- `beta.reviewer2@alunos.ufv.br`

As duas estao com perfil completo, 18+, conexao aceita e conversa inicial. As
credenciais estao no arquivo temporario
`C:\Users\PANFYL~1\AppData\Local\Temp\opencode\play-test-accounts.txt`.

Coloque as credenciais no campo **App access** do Play Console e apague o arquivo
depois. Nunca commite as senhas.

## Testadores

1. Criar Google Group ou lista de emails.
2. Subir o AAB no teste interno/fechado.
3. Copiar o link de opt-in.
4. Enviar instrucoes; o tester precisa usar a mesma conta Google do celular.
5. Meta: 30 a 50 convidados para garantir 12 opt-in por 14 dias.

## Assets

- Icone 512: `docs/play/icon-512.png`.
- Feature graphic 1024x500: `docs/play/feature-graphic-1024x500.png`.
- Screenshots: capturar no celular durante o teste interno.

## AAB

```powershell
flutter build appbundle --release --build-name=1.0.15 --build-number=19
```

Saida: `app/build/app/outputs/bundle/release/app-release.aab`.

## Riscos

- Reprovação por UGC/relacionamento: manter posicionamento social 18+, sem
  conteudo explicito.
- Conta de teste obrigatoria (cadastro restrito a emails UFV).
- Play App Signing muda a assinatura: desinstalar APK manual.
- 12 testadores precisam ficar opt-in por 14 dias continuos.
