# Mapa de Telas

## Estrutura de navegação
```
App
├── Onboarding (sem login)
│   ├── Boas-vindas / 18+
│   ├── Criar conta
│   ├── Consentimentos
│   ├── Verificação de identidade
│   ├── Montar perfil
│   ├── Preferências
│   └── Tutorial (1x) / Notificações
└── Principal (logado)
    ├── Feed
    │   ├── Abas: Para Você / Conexão
    │   ├── FAB → Publicar / Publicar em grupo / Criar grupo
    │   ├── Publicação (visibilidade, tópicos, cargo, citação)
    │   └── Detalhe do post (respostas de até 3 níveis, citação, moderação)
    ├── Descobrir
    │   ├── Pessoas
    │   ├── Grupos (diretório público + perfil de grupo)
    │   └── Estudos
    ├── Conversas
    │   └── Chat
    ├── Perfil de grupo (membros, cargos, seguidores, convites)
    ├── Criar / Gerenciar grupo
    └── Configurações
```
```
Admin (web)
├── Fila de moderação
├── Aprovar grupos públicos (selo oficial)
├── Gestão de usuários
├── Estudos pendentes
└── Denúncias
```

## Fluxo principal (onboarding)
```
[18+] -> [Conta] -> [Consentimentos] -> [Documento] -> [Selfie] -> [Resultado]
   |                                                                  |
   +------------------------- (falha) -> [Revisão] <------------------+
                                                                      |
[Perfil] <- [Estilo de relação] <- [Interesses] <- [Prompts] <- [Fotos]
   |
[Preferências] -> [Localização] -> [Descobrir]
```

---

## Wireframes (baixa fidelidade)

### 1. Boas-vindas / 18+
```
+----------------------------------+
|                                  |
|         [ marca / nome ]         |
|                                  |
|   Um espaço para conexões reais  |
|                                  |
|   Este app é para maiores de 18  |
|                                  |
|   [ Tenho 18 anos ou mais ]      |
|   [ Sair ]                       |
+----------------------------------+
```

### 2. Criar conta
```
+----------------------------------+
|  <                               |
|  Criar conta                     |
|                                  |
|  E-mail                          |
|  [__________________________]    |
|                                  |
|  Senha                           |
|  [__________________________]    |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 3. Consentimentos
```
+----------------------------------+
|  <  Privacidade e consentimento  |
|                                  |
|  [x] Termos de Uso               |
|  [x] Política de Privacidade     |
|  [ ] Uso de biometria (selfie)   |
|      (obrigatório p/ verificar)  |
|  [ ] Localização aproximada      |
|                                  |
|  [ Aceitar e continuar ]         |
+----------------------------------+
```

### 4. Verificação — documento
```
+----------------------------------+
|  <  Verificação (1/3)            |
|                                  |
|  Frente da CIN/CNH               |
|  +----------------------------+  |
|  |      [ câmera ]            |  |
|  |   enquadre o documento     |  |
|  +----------------------------+  |
|                                  |
|  Verso com QR Code               |
|  +----------------------------+  |
|  |      [ câmera ]            |  |
|  +----------------------------+  |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 5. Verificação — selfie/liveness
```
+----------------------------------+
|  <  Verificação (2/3)            |
|                                  |
|        +------------+            |
|        |   ( rosto )|            |
|        |            |            |
|        +------------+            |
|                                  |
|  Olhe para a câmera e pisque     |
|                                  |
|  [ Iniciar prova de vida ]       |
+----------------------------------+
```

### 6. Resultado
```
+----------------------------------+
|  Verificação (3/3)               |
|                                  |
|            ( ok )                |
|                                  |
|  Identidade confirmada           |
|  Você tem 18 anos ou mais        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 7. Perfil — fotos
```
+----------------------------------+
|  <  Seu perfil (1/4)             |
|                                  |
|  Adicione fotos                  |
|  +--------+ +--------+           |
|  | foto 1 | | foto 2 |           |
|  +--------+ +--------+           |
|  +--------+ +--------+           |
|  | +      | | +      |           |
|  +--------+ +--------+           |
|                                  |
|  Dica: luz natural e rosto       |
|  visível funcionam melhor        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 8. Perfil — prompts
```
+----------------------------------+
|  <  Seu perfil (2/4)             |
|                                  |
|  Responda 3 prompts              |
|                                  |
|  "Um domingo perfeito é..."      |
|  [__________________________]    |
|                                  |
|  "Procuro alguém que..."         |
|  [__________________________]    |
|                                  |
|  "Meu maior talento é..."        |
|  [__________________________]    |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 9. Perfil — estilo de relação
```
+----------------------------------+
|  <  Seu perfil (3/4)             |
|                                  |
|  Como você se relaciona?         |
|  ( ) Monogamia                   |
|  ( ) Não-monogamia               |
|  ( ) Casal / trisal              |
|  ( ) Prefiro não dizer           |
|                                  |
|  [ ] Estou em um relacionamento  |
|      -> Vincular parceiro        |
|                                  |
|  [ Continuar ]                   |
+----------------------------------+
```

### 10. Preferências
```
+----------------------------------+
|  <  Preferências                 |
|                                  |
|  Quero ver                       |
|  [ Gênero v ] [ Idade v ]        |
|  [ Distância v ] [ Intenção v ]  |
|                                  |
|  [ Começar a usar ]              |
+----------------------------------+
```

### 11. Descobrir (feed)
```
+----------------------------------+
|  Descobrir              [filtros]|
|                                  |
|  +----------------------------+  |
|  |        [ foto ]            |  |
|  |                            |  |
|  |  Ana, 24                  |  |
|  |  "Um domingo perfeito é..."|  |
|  +----------------------------+  |
|                                  |
|  [ X ]        [ ♥ ]     [ -> ]   |
|                                  |
|  (próximo perfil...)             |
+----------------------------------+
```

### 12. Detalhe do perfil
```
+----------------------------------+
|  <                        [ ... ]|
|  +----------------------------+  |
|  |        [ foto ]            |  |
|  +----------------------------+  |
|  Ana, 24                         |
|  Relaciona-se com @bia          |
|                                  |
|  Prompt 1 ...                    |
|  Prompt 2 ...                    |
|                                  |
|  [ ♥ Curtir ]   [ Enviar msg ]  |
+----------------------------------+
```

### 13. Curtidas / Conexões
```
+----------------------------------+
|  Curtidas                        |
|  [ Quem curtiu você ]            |
|  +------+ +------+ +------+      |
|  | foto | | foto | | foto |      |
|  +------+ +------+ +------+      |
|                                  |
|  Conexões                        |
|  +------+ +------+               |
|  | foto | | foto |               |
|  +------+ +------+               |
+----------------------------------+
```

### 14. Lista de conversas
```
+----------------------------------+
|  Conversas                       |
|  +------+ Ana           12:40   |
|  | foto | última msg...         |
|  +------+                        |
|  +------+ Bia           10:12   |
|  | foto | última msg...         |
|  +------+                        |
+----------------------------------+
```

### 15. Chat
```
+----------------------------------+
|  <  Ana                   [ ... ]|
|                                  |
|         [ oi! tudo bem? ]        |
|  [ e aí, o que você curte? ]     |
|                                  |
|  +----------------------------+  |
|  | [ aviso de segurança ]     |  |
|  | "Mensagem pode ser invasiva"| |
|  +----------------------------+  |
|                                  |
|  [ Coach ] [___________] [ -> ]  |
+----------------------------------+
```

### 16. AI Coach (assinante)
```
+----------------------------------+
|  <  Coach                        |
|                                  |
|  [ Dicas de foto ]               |
|  [ Sugerir abertura ]            |
|  [ Analisar meu perfil ]         |
|                                  |
|  Sugestão para Ana:              |
|  "Você também curte trilhas?    |
|   Qual foi a última que fez?"    |
|                                  |
|  [ Copiar ]  [ Usar ]            |
+----------------------------------+
```

### 17. Assinatura
```
+----------------------------------+
|  <  Assinatura                   |
|                                  |
|  Grátis: filtros básicos         |
|  Assinante: filtros + Coach      |
|                                  |
|  ( ) R$ 10/mês                   |
|  ( ) R$ 5/mês (indicação)        |
|  ( ) Anual (desconto)            |
|                                  |
|  [ Assinar com Pix ]             |
+----------------------------------+
```

### 18. Configurações
```
+----------------------------------+
|  <  Configurações                |
|  Privacidade e consentimentos    |
|  Localização                     |
|  Segurança                       |
|  Bloquear usuários               |
|  Excluir conta                   |
+----------------------------------+
```

### 19. Denúncia / Bloqueio
```
+----------------------------------+
|  <  Denunciar                    |
|                                  |
|  Motivo:                         |
|  ( ) Assédio                     |
|  ( ) Perfil falso                |
|  ( ) Imagem sem consentimento    |
|  ( ) Menor de idade              |
|  ( ) Outro                       |
|                                  |
|  [ Enviar denúncia ]             |
|  [ Bloquear usuário ]            |
+----------------------------------+
```

---

## 1.0.14 — Feed e Grupos

### F.1 Feed (abas + FAB)
```
+----------------------------------+
| Feed UFV                   [sino]|
| [ Para você | Conexão ]          |
| +----------------------------+  |
| | Ana · C. da Computação     |  |
| | "roda de conversa..."      |  |
| | [Diretoria · CAC] (cargo)  |  |
| | [curso][campus][evento]    |  |
| | ( 48 curtidas, 6 respostas )| |
| | Republicar                 |  |
| +----------------------------+  |
|                        ( FAB + ) |
+----------------------------------+
FAB -> Publicar / Publicar em grupo / Criar grupo
```

### F.2 Página de publicação
```
+----------------------------------+
| <  Publicar                      |
| [ texto: o que compartilhar? ]   |
| Quem pode ver: (Público|Conexões)|
| Tópicos: curso / campus /        |
|          categorias (até 3)      |
| Selo de cargo (grupos verif.)    |
| Em grupo: cargo + "em nome"      |
| [ Publicar ]                     |
+----------------------------------+
```

### F.3 Perfil de grupo
```
+----------------------------------+
| <  Grupo                  [...]  |
| [avatar] Centro Acad. Comp.      |
| [Grupo oficial][cat][campus]     |
| Membros 12 . Seguidores 340      |
| [ Entrar/Sair ] [ Seguir ]       |
| [Membros][Cargos][Seguidores]    |
| [Convites]                       |
+----------------------------------+
Convites: criar (validade/usos) ->
copiar link 1x -> status -> revogar
```

### F.4 Aprovação de grupo (admin)
```
+----------------------------------+
| <  Aprovar grupos                |
| +----------------------------+  |
| | Grupo X · cat · campus     |  |
| | descrição...               |  |
| | [ Rejeitar ] [ Aprovar ]   |  |
| +----------------------------+  |
+----------------------------------+
```

---

## 1.0.15 - Feedback

Rotas: `/feedback`, `/feedback/bug`, `/feedback/suggestion` e `/admin/feedback`.
Entradas: Ajuda, Ajustes e ícone na Administração.

### FB.1 Feedback (home)
```
+----------------------------------+
| <  Feedback                      |
| Ajude a melhorar o Conexa        |
| [ Reportar um problema      > ]  |
| [ Enviar uma sugestão       > ]  |
|                                  |
| Meus envios                      |
| BUG-000123  [Recebido]           |
| Enviado agora                    |
+----------------------------------+
```

### FB.2 Reportar problema
```
+----------------------------------+
| <  Reportar problema             |
| Título                           |
| O que aconteceu?                 |
| > Detalhes opcionais             |
|   Passos / esperado / acontecido |
|   Aparelho e sistema             |
| [ Anexar print (opcional) ]      |
| [ Enviar relato ]                |
+----------------------------------+
```

### FB.3 Enviar sugestão
```
+----------------------------------+
| <  Enviar sugestão               |
| Título                           |
| Descreva a sugestão              |
| > Detalhes opcionais             |
|   Problema / proposta / impacto  |
| [ Enviar sugestão ]              |
+----------------------------------+
```

### FB.4 Feedback no admin
```
+----------------------------------+
| <  Feedback                      |
| [ Bugs ] [ Sugestões ]           |
| (Abertos)(Em andamento)(Encerr.) |
| +----------------------------+   |
| | Título                     |   |
| | BUG-000123 · status · tempo|   |
| +----------------------------+   |
| toque -> detalhe + print +       |
|          mudança de status       |
+----------------------------------+
```

---

## 1.0.17 - Privacidade e confianca (P0)

Rotas: `/security`, `/muted-users`, `/muted-words`, `/my-reports` e
`/admin/appeals`.
Entradas: Ajustes > Seguranca e privacidade; perfil > Silenciar; admin > Apelacoes.

### P0.1 Seguranca e privacidade
```
+----------------------------------+
| <  Seguranca e privacidade       |
| Dispositivos conhecidos          |
| Android . Conexa 1.0.17  ontem   |
|                                  |
| Usuarios silenciados          >  |
| Palavras silenciadas          >  |
| Meus relatos                  >  |
| Exportar meus dados           >  |
| [ Sair de todos os dispositivos] |
+----------------------------------+
```

### P0.2 Apelacao
```
+----------------------------------+
| <  Meus relatos                  |
| Assedio . Recebida               |
| Status: Encerrada                |
| Acao: hide                       |
| [ Apelar ]                       |
+----------------------------------+
```

---

## 1.0.18 - Feed social P1

Rotas: `/feed/scheduled`, `/feed/saved`, `/feed/hidden`, `/feed/search`,
`/feed/feeds`, `/feed/feeds/:id` e `/insights`.
Entradas: FAB > Publicar; FAB > Salvos; FAB > Rascunhos e agendados; menu do post.

### P1.1 Composer
```
+----------------------------------+
| <  Publicar              Publicar|
| [ texto ]                        |
| Midia: [Imagem]                  |
|   [alt de cada imagem]           |
| Enquete: 2-4 opcoes + 24h/3d/7d  |
| Mencoes: [Mencionar conexoes]    |
| Quem pode ver / responder        |
| Topicos / cargo / selo           |
| [Salvar rascunho] [Agendar]      |
+----------------------------------+
```

### P1.2 Card
```
+----------------------------------+
| autor · agora · editado · pin    |
| [Republicou]                     |
| texto                            |
| [midia: imagem]                  |
| [enquete com votos]              |
| @mencao                          |
| curtir . responder . republicar  |
| menu: salvar/editar/fixar/...    |
+----------------------------------+
```

### P1.3 Rascunhos e agendados
```
+----------------------------------+
| <  Rascunhos e agendados         |
| [ Agendados | Rascunhos ]        |
| texto                            |
| status . data . erro             |
| [Cancelar] ou [Usar][Apagar]     |
+----------------------------------+
```

### P1.4 Salvos
```
+----------------------------------+
| <  Salvos                        |
| [ card do post salvo ]           |
| menu: remover dos salvos         |
+----------------------------------+
```

---

## 1.0.19 - Chat social P2

Rotas: `/chats`, `/chats/:id` (agora com grupos, reply, reações e mídia).
Sem novas rotas obrigatórias; ações ficam em menus e bottom sheets.

### P2.1 Lista de conversas
```
+----------------------------------+
| Conversas       [arquivo] [+grupo]|
| [busca]                          |
| [Mensagens][Pedidos][Conexões]   |
| [grupo] titulo . N participantes |
| fixado . silenciado . nao lidas  |
| menu: fixar/silenciar/arquivar   |
+----------------------------------+
```

### P2.2 Chat
```
+----------------------------------+
| <  Grupo . 5 participantes  [...]|
| [reply/quote da mensagem]        |
| [nome do remetente no grupo]     |
| texto / imagem / PDF             |
| reacoes: 👍 2  ❤️ 1              |
| editada . hora                   |
| [anexo][texto][emoji][enviar]    |
| [Fulano esta digitando...]       |
+----------------------------------+
```

### P2.3 Ações
```
Mensagem: reagir / responder / editar / apagar / denunciar
Conversa: participantes / fixar / silenciar / arquivar / limpar / excluir
```

---

## 1.0.20 - Descoberta P3

Rotas: `/feed/search`, `/feed/feeds`, `/feed/feeds/:id` e `/insights`.
Entradas: lupa no feed; FAB > Feeds personalizados; Ajustes > Insights; menu do post.

### P3.1 Busca global
```
+----------------------------------+
| <  Buscar publicacoes            |
| [ buscar no feed... ]            |
| [ card de resultado ]            |
| [ card de resultado ]            |
+----------------------------------+
```

### P3.2 Feeds personalizados
```
+----------------------------------+
| <  Feeds personalizados       [+]|
| [ feed . N topicos ]          [x]|
| [ feed . N topicos ]          [x]|
+----------------------------------+
Novo feed: nome + ate 5 topicos.
```

### P3.3 Insights
```
+----------------------------------+
| <  Insights                      |
| [ publicacoes ][ curtidas ]      |
| [ respostas ][ reposts ]         |
| [ salvos ][ votos ]              |
| Principais publicacoes           |
+----------------------------------+
```

---

## 1.0.21 - Grupos e estudos P4

Rotas: `/groups/:id/insights`, `/studies/questions`, `/studies/questions/:id`
e `/studies/saved`. Sem mudar a navegação principal.

### P4.1 Grupo
```
+----------------------------------+
| <  Grupo        [chat] [insights]|
| [Membros][Cargos][Seguidores]    |
| [Eventos][Convites]              |
| Evento . data . local            |
| [Novo evento] (gestor)           |
+----------------------------------+
```

### P4.2 Chat do grupo
```
+----------------------------------+
| <  Grupo . N participantes       |
| mensagens (mesmo chat P2)        |
| entrada/saida de membro sincroniza|
+----------------------------------+
```

### P4.3 Q&A
```
+----------------------------------+
| <  Perguntas da disciplina   [+] |
| titulo . autor . N respostas     |
| resolvida [ok]                   |
+----------------------------------+
Pergunta:
| respostas . aceitar . votar      |
| [escrever resposta]              |
+----------------------------------+
```

### P4.4 Materiais salvos e avaliacoes
```
+----------------------------------+
| <  Material                      |
| [Salvar] 4.5 . N avaliacoes      |
| [*][*][*][*][*]                  |
| Materiais salvos (lista)         |
+----------------------------------+
```

---

## 1.0.22 - Hardening P5

Rotas novas: `/admin/moderation-terms`, `/feed/hidden`, `/feed/search`
(com aba Comentarios), `/groups/:id/insights` e `/studies/questions` (com busca).

### P5.1 Termos de moderacao (admin)
```
+----------------------------------+
| <  Termos de moderacao       [+] |
| termo                [x] ativo   |
| categoria                        |
+----------------------------------+
```

### P5.2 Chat do grupo
```
Participantes
[ Adicionar ]
Fulano  [remover]
Ciclano
```

### P5.3 Evento
```
Evento . data . local
3 confirmados . 2 interessados
[ Vou ] [ Interesse ] [ Nao vou ]
```

### P5.4 Q&A
```
Pergunta: texto + anexos (imagem/PDF)
[ Anexar imagem/PDF ] (autor)
Respostas: texto + anexos + votos
[ Aceitar ] (autor da pergunta)
Busca: [ buscar perguntas... ]
```

### P5.5 Avaliacao
```
[*****] 4.5 . N avaliacoes
[ Avaliar com comentario ]
Comentarios publicos (nome + nota + texto)
```

### P6.1 Aparencia
```
Ajustes > Aparencia
[ Ceruleo & Cereja ] [ Meia-noite & Coral ] ...
Previa: 3 cores + nome
Aplicar skin (persistida no aparelho)
```

### P6.2 Gestao do grupo
```
Membros > menu do membro
[ Atribuir cargos ]
[ Transferir gestao ] (Dono)
[ Adicionar administrador ] (CA/DA/Republica)
[ Remover administrador ]
[ Remover membro ]
```

### P7.1 Hub
```
[avatar]            Conexa            [pessoa+]
Feed | Buscar | Mapa | Notificacoes | Chat
```

### P7.2 Pessoas
```
Pessoas
[ buscar pessoas... ]
Solicitacoes recebidas [Aceitar] [Recusar]
Solicitacoes enviadas [Cancelar]
Suas conexoes [Perfil]
Sugestoes [Conectar]
```

### P7.3 Buscar
```
[ buscar disciplina, tema, professor... ]
[letreiro de eventos]
[Tudo] [Materiais] [Disciplinas] [Professores] [Q&A]
```

### P7.4 Mapa
```
[avatar] Mapa [pessoa+]
[ Todos ] [ Pavilhao ] [ Comida ] [ Farmacia ] ...
mapa OSM + pinos aprovados
[ Sugerir local ] -> toque no mapa -> formulario pending
```

### P7.5 Menu do avatar
```
[avatar] -> menu lateral
Nome, UFV, conexoes
Perfil
Assinatura
Meus grupos
Ajustes
```

---

## Ordem de construção das telas
1. **B1:** 1–6 (18+, conta, consentimento, verificação).
2. **B2:** 7–10 + 18 (perfil, estilo de relação, preferências, configurações).
3. **B3:** 11–13 (descobrir, detalhe, curtidas).
4. **B4:** 14–15 + 19 (conversas, chat, denúncia).
5. **B5:** 16 (Coach).
6. **B6:** mapa/perto de você.
7. **B7:** 17 (assinatura).
8. **B8/B9:** admin web.
