# O que não copiar do X e do Threads

> Regra central: **copie a função, nunca a expressão**. No Brasil, ideia,
> procedimento e método não são protegidos por direito autoral (Lei 9.610/98,
> art. 8º). O que é protegido: código, textos, imagens, áudio, identidade visual,
> marca e a combinação que confunde o consumidor. Também valem contratos e
> termos de uso das plataformas.

## 1. Código e engenharia

Não copie:

- código-fonte, trechos, classes, comentários, arquitetura interna;
- APK decompilado, engenharia reversa, hooks, scrapers, automação de contas;
- uso de API não oficial, burla de rate limit ou extração de dados;
- algoritmo de ranking/recomendação, targeting de anúncios, prompts internos;
- SDKs e arquivos proprietários do X, Threads ou Meta.

Pode:

- implementar a mesma função do zero, com código próprio;
- usar open source com licença compatível (MIT/Apache/BSD); GPL exige cuidado;
- usar Flutter, Material, Supabase e as bibliotecas já adotadas.

## 2. Marca, nome e identidade visual

Não copie:

- nomes ou marcas: X, Twitter, Tweet, Threads, Meta, Instagram, Grok, Spaces,
  Reels, "blue check", "Community Notes";
- logos, ícones, fontes, paletas, ilustrações, sons, animações, splash screens,
  emojis customizados;
- layout pixel-perfect de card, linha de thread, perfil ou tela de mensagens;
- combinação de cores, tipografia e formas que faça o usuário confundir o
  Conexa com X ou Threads. Isso é trade dress e concorrência desleal
  (Lei 9.279/96).

Pode:

- usar padrões genéricos: feed, abas, cards, bottom sheet, coração, balão de
  resposta, seta de repostar;
- inspirar-se no fluxo, desde que a aparência seja claramente do Conexa;
- manter a identidade do Conexa: papel `#F6F2EA`, tinta `#14130F`, teal
  `#0F5C5C`, Newsreader + IBM Plex Sans.

Nomes seguros:

- "publicação" em vez de "tweet";
- "republicar" em vez de "retweet/repost";
- "sequência" ou "respostas encadeadas" em vez de "thread";
- "salvar" em vez de "bookmark";
- "enquete" em vez de "poll";
- "sala de áudio" em vez de "Spaces";
- "grupos/comunidades do campus" em vez de "Communities";
- "verificação institucional" em vez de "selo azul".

## 3. Conteúdo, textos e dados

Não copie:

- textos de políticas, FAQ, tutoriais, onboarding, notificações, e-mails ou
  mensagens de erro;
- screenshots, vídeos, imagens, áudios, GIFs, stickers, fontes ou emojis;
- posts, perfis, fotos, DMs, listas ou seguidores de usuários;
- dados de usuários para treinar IA sem base legal e consentimento;
- "importar seguidores" ou contatos sem consentimento.

Pode:

- escrever textos próprios, com o tom do Conexa;
- criar ícones próprios ou usar Material Icons;
- usar dados agregados e anonimizados para métricas internas.

## 4. Funcionalidades com risco específico

- **Patentes:** não copie implementações específicas de mecânicas patenteadas.
  Feed, curtir, responder, repostar, salvar, enquete, silenciar e bloquear são
  mecânicas consolidadas; implemente do zero.
- **E2EE:** não copie a arquitetura do XChat. Se implementar, use protocolo
  auditado (Signal/MLS) e não alegue segurança sem auditoria.
- **Bloqueio de screenshot:** não copie; não é segurança real.
- **Verificação paga:** não copie; conflita com verificação institucional.
- **Anúncios/venda de dados:** não copie; princípio do Conexa.
- **Localização exata:** não copie; LGPD e segurança física.
- **Liberdade absoluta:** não copie; moderação forte.
- **Convite por link:** não copie; o Conexa usa convite in-app por segurança.
- **Trends/notas da comunidade:** pode adaptar, mas exige moderação e
  transparência; não copie o modelo sem regras.
- **Fediverso:** protocolo aberto, mas não copie a implementação; avalie custo e
  privacidade.
- **IA:** não copie prompts, modelos ou marca; use IA própria com política de
  dados e sem treinar em dados do usuário.
- **Analytics demográfico:** não copie; colete o mínimo e agregue.

## 5. Lista definitiva do Conexa

Não será copiado:

1. Venda de dados.
2. Selo azul pago.
3. Localização exata.
4. Bloqueio de prints.
5. Liberdade absoluta para falar o que quiser, inclusive ódio e discriminação.

Também ficam fora por decisão de produto:

- anúncios e venda de dados;
- convite de grupo por link;
- algoritmo de recomendação copiado;
- importação de seguidores/contatos;
- verificação paga;
- analytics demográfico;
- alegação de E2EE sem auditoria;
- bloqueio de screenshot como promessa de segurança.

## 6. Moderação forte

O Conexa é ambiente de aprendizado e convivência universitária. Não é lugar
para racismo, LGBTfobia, misoginia, capacitismo, xenofobia, intolerância
religiosa, neonazismo, apologia à tortura ou à ditadura, ameaça, assédio,
doxxing, CSAM, imagem íntima sem consentimento, fraude acadêmica, spam ou
impersonação.

Aplicação:

- regras públicas e iguais para todos;
- denúncia fácil, auto-hide com 3 denunciantes e revisão humana;
- punição progressiva: aviso, remoção, suspensão e banimento;
- apelação e registro de decisão;
- moderação no servidor (RLS, triggers e RPCs), não só na UI;
- ranking não amplifica ódio;
- sem anonimato total: e-mail institucional + 18+;
- discussão acadêmica de temas sensíveis é permitida com contexto e respeito;
  apologia não é;
- transparência por meio de relatório periódico.

Base legal: CF/88 (art. 5º, IV, VI, VIII, X, XLII), Lei 7.716/89,
Lei 14.532/23, Marco Civil, LGPD e ECA quando aplicável.
